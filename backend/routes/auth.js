const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const Season = require('../models/Season');
const authMiddleware = require('../middleware/auth');
const { sendOtpEmail } = require('../utils/mailer');
const progression = require('../utils/progression');

const router = express.Router();

const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '30d' });
};

const RESET_OTP_TTL_MS = 10 * 60 * 1000; // OTP หมดอายุใน 10 นาที
const generateOtp = () => Math.floor(100000 + Math.random() * 900000).toString();

// @route   POST /api/auth/register
// @desc    สมัครสมาชิกด้วย email + password
router.post('/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ message: 'This email is already registered' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const user = await User.create({
      email,
      password: hashedPassword,
      displayName: displayName || email.split('@')[0],
      isGuest: false,
    });

    const token = generateToken(user._id);

    res.status(201).json({
      token,
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        isGuest: user.isGuest,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/login
// @desc    เข้าสู่ระบบด้วย email + password
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user) {
      return res.status(401).json({ message: 'Incorrect email or password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Incorrect email or password' });
    }

    const token = generateToken(user._id);

    res.json({
      token,
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        isGuest: user.isGuest,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/guest
// @desc    เข้าสู่ระบบแบบ guest (ไม่ต้องสมัครสมาชิก)
router.post('/guest', async (req, res) => {
  try {
    const user = await User.create({
      isGuest: true,
      displayName: `Guest${Math.floor(Math.random() * 100000)}`,
    });

    const token = generateToken(user._id);

    res.status(201).json({
      token,
      user: {
        id: user._id,
        displayName: user.displayName,
        isGuest: user.isGuest,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/auth/me
// @desc    ดึงข้อมูล user ปัจจุบัน + ความคืบหน้า (level/xp/rank) + สถิติ สำหรับหน้า Profile/Home
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const activeSeason = await Season.findOne({ isActive: true });

    // ยิงพร้อมกันทีเดียว ไม่ต้องรอทีละ query
    const [questCompleted, questTotal, questAgg, seasonAgg] = await Promise.all([
      QuestHistory.countDocuments({ userId: user._id }),
      Quest.countDocuments({ isActive: true }),
      // partiesJoined + co2SavedKg ต้อง join ไปหา Quest เพราะข้อมูลอยู่ที่ template ของ quest
      QuestHistory.aggregate([
        { $match: { userId: user._id } },
        {
          $lookup: {
            from: 'quests',
            localField: 'questId',
            foreignField: '_id',
            as: 'quest',
          },
        },
        { $unwind: '$quest' },
        {
          $group: {
            _id: null,
            partiesJoined: {
              $sum: { $cond: [{ $eq: ['$quest.type', 'party'] }, 1, 0] },
            },
            co2SavedKg: { $sum: { $ifNull: ['$quest.co2SavedKg', 0] } },
          },
        },
      ]),
      // XP เฉพาะที่ได้ภายใน season ปัจจุบัน — ใช้คิด Rank (ไม่มี season active = ยังไม่เริ่มนับ)
      activeSeason
        ? QuestHistory.aggregate([
            {
              $match: {
                userId: user._id,
                completedAt: { $gte: activeSeason.startDate, $lte: activeSeason.endDate },
              },
            },
            { $group: { _id: null, xp: { $sum: '$xpEarned' } } },
          ])
        : Promise.resolve([]),
    ]);

    const { partiesJoined = 0, co2SavedKg = 0 } = questAgg[0] || {};
    const seasonXp = seasonAgg[0]?.xp || 0;

    // level/rank คิดสดจาก xp เสมอ (xp คือ source of truth ตามดีไซน์)
    // ฟิลด์ user.level / user.rank ที่เก็บใน DB เป็นแค่ cache ไว้ query — ตอนทำ quest สำเร็จค่อยเขียนทับให้ตรง
    const progress = {
      ...progression.levelProgress(user.xp),
      ...progression.rankProgress(seasonXp),
    };

    res.json({
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        isGuest: user.isGuest,
        level: progress.level,
        xp: user.xp,
        points: user.points,
        rank: progress.rankTier,
        energy: progression.currentEnergy(user.energy, user.lastEnergyUpdate),
      },
      progress,
      stats: {
        questCompleted,
        questTotal,
        co2SavedKg,
        partiesJoined,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/verify-password
// @desc    เช็ครหัสผ่านปัจจุบันว่าถูกไหม — ใช้ก่อนขั้นตอนกรอกรหัสผ่านใหม่ในหน้า Change Password
// (ฝั่ง /change-password ก็ยัง verify ซ้ำอีกชั้นตอนเปลี่ยนจริง ไม่ได้พึ่ง endpoint นี้เป็นการตรวจครั้งเดียว)
router.post('/verify-password', authMiddleware, async (req, res) => {
  try {
    const { password } = req.body;
    if (!password) {
      return res.status(400).json({ message: 'Please enter your password' });
    }

    const user = await User.findById(req.userId);
    if (!user || user.isGuest) {
      return res.status(400).json({ message: 'Guest accounts do not have a password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Incorrect password' });
    }

    res.json({ message: 'Password verified' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/change-password
// @desc    เปลี่ยนรหัสผ่าน (ต้อง login อยู่แล้ว + รู้รหัสผ่านเดิม)
router.post('/change-password', authMiddleware, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Current and new password are required' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters' });
    }

    const user = await User.findById(req.userId);
    if (!user || user.isGuest) {
      return res.status(400).json({ message: 'Guest accounts have no password to change' });
    }

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Current password is incorrect' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.json({ message: 'Password changed successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    ขอ OTP ไปยังอีเมล เพื่อใช้ตั้งรหัสผ่านใหม่ (ลืมรหัสผ่าน)
router.post('/forgot-password', async (req, res) => {
  // ตอบข้อความเดียวกันเสมอไม่ว่าจะเจออีเมลนี้ในระบบหรือไม่ กันคนเดารายชื่ออีเมลที่สมัครไว้
  const genericResponse = { message: 'If this email is registered, we have sent an OTP to it' };

  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user) {
      return res.json(genericResponse);
    }

    const otp = generateOtp();
    const salt = await bcrypt.genSalt(10);
    user.resetOtpHash = await bcrypt.hash(otp, salt);
    user.resetOtpExpires = new Date(Date.now() + RESET_OTP_TTL_MS);
    await user.save();

    await sendOtpEmail(user.email, otp);

    res.json(genericResponse);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to send OTP. Please try again' });
  }
});

// @route   POST /api/auth/verify-reset-otp
// @desc    ยืนยัน OTP ที่ได้รับทางอีเมล แลกเป็น reset token อายุสั้นไว้ตั้งรหัสผ่านใหม่
router.post('/verify-reset-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ message: 'Email and OTP are required' });
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user || !user.resetOtpHash || !user.resetOtpExpires || user.resetOtpExpires < new Date()) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }

    const isMatch = await bcrypt.compare(otp, user.resetOtpHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }

    // ใช้ OTP ได้ครั้งเดียว — ล้างทิ้งทันทีที่ยืนยันผ่าน กันเอาไปใช้ซ้ำ
    user.resetOtpHash = null;
    user.resetOtpExpires = null;
    await user.save();

    const resetToken = jwt.sign(
      { userId: user._id, purpose: 'password_reset' },
      process.env.JWT_SECRET,
      { expiresIn: '10m' }
    );

    res.json({ resetToken });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/reset-password
// @desc    ตั้งรหัสผ่านใหม่ด้วย reset token ที่ได้จาก /verify-reset-otp
router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword } = req.body;
    if (!resetToken || !newPassword) {
      return res.status(400).json({ message: 'Missing required information' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters' });
    }

    let decoded;
    try {
      decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
    } catch (err) {
      return res.status(401).json({ message: 'This password reset request has expired. Please request a new OTP' });
    }

    if (decoded.purpose !== 'password_reset') {
      return res.status(401).json({ message: 'Invalid token' });
    }

    const user = await User.findById(decoded.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
