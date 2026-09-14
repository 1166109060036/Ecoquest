const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const { sendOtpEmail } = require('../utils/mailer');
const { buildProfileStats } = require('../utils/profilePayload');
const { avatarUrlFor } = require('../utils/avatar');

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
    // -avatarData กัน Buffer รูปโปรไฟล์ (อาจหนักหลายร้อย KB) ถูกดึงมาด้วยทั้งที่ route นี้
    // ไม่ได้ใช้ตัวไฟล์เลย ใช้แค่ avatarContentType/avatarUpdatedAt ไปสร้าง avatarUrl พอ
    const user = await User.findById(req.userId).select('-password -avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // progress (level/xp/rank) + stats (จำนวนเควส/CO2/ปาร์ตี้) ใช้ตัวช่วยร่วมกับ
    // GET /users/:id (ดูโปรไฟล์คนอื่น) เพื่อให้คิดเลขแบบเดียวกันเป๊ะๆ
    const { progress, stats } = await buildProfileStats(user);

    res.json({
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        isGuest: user.isGuest,
        avatarUrl: avatarUrlFor(user),
        level: progress.level,
        xp: user.xp,
        points: user.points,
        rank: progress.rankTier,
        notificationsEnabled: user.notificationsEnabled,
      },
      progress,
      stats,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// รูปที่ยอมรับ — จำกัดแค่ 2 แบบนี้พอ ไม่ต้องรองรับทุก mime type ที่มือถือส่งมาได้
const ALLOWED_AVATAR_TYPES = ['image/jpeg', 'image/png'];
// กันไฟล์ใหญ่ผิดปกติ (image_picker ฝั่งแอพย่อเหลือ maxWidth 800 อยู่แล้ว ปกติไม่เกินนี้)
const MAX_AVATAR_BYTES = 4 * 1024 * 1024;

// @route   POST /api/auth/avatar
// @desc    ตั้ง/ลบรูปโปรไฟล์จริง — ส่ง { avatarBase64, contentType } มาเพื่อตั้ง
//          หรือส่ง { avatarBase64: null } มาเพื่อลบ
// เก็บไฟล์เป็น Buffer ในเอกสาร User ตรงๆ (ไม่ใช้ cloud storage แยก ไม่ต้องพึ่ง
// credential/บริการภายนอกเพิ่ม) เสิร์ฟกลับผ่าน GET /api/users/:id/avatar
router.post('/avatar', authMiddleware, async (req, res) => {
  try {
    const { avatarBase64, contentType } = req.body;

    const user = await User.findById(req.userId).select('-password -avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (avatarBase64 == null) {
      user.avatarData = null;
      user.avatarContentType = null;
      user.avatarUpdatedAt = null;
      await user.save();
      return res.json({ message: 'Avatar removed', avatarUrl: null });
    }

    if (typeof avatarBase64 !== 'string' || !ALLOWED_AVATAR_TYPES.includes(contentType)) {
      return res.status(400).json({ message: 'Invalid avatar data' });
    }

    const buffer = Buffer.from(avatarBase64, 'base64');
    if (buffer.length === 0 || buffer.length > MAX_AVATAR_BYTES) {
      return res.status(400).json({ message: 'Avatar image is too large' });
    }

    user.avatarData = buffer;
    user.avatarContentType = contentType;
    user.avatarUpdatedAt = new Date();
    await user.save();

    res.json({ message: 'Avatar updated', avatarUrl: avatarUrlFor(user) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// จำกัดความยาวชื่อที่แสดง — กันคนตั้งชื่อยาวจนล้นการ์ด/แถบอันดับในหน้า Profile
const MAX_DISPLAY_NAME_LENGTH = 20;

// @route   POST /api/auth/display-name
// @desc    แก้ไขชื่อที่แสดง (ใช้ได้ทั้ง guest และบัญชีปกติ)
router.post('/display-name', authMiddleware, async (req, res) => {
  try {
    const displayName = (req.body.displayName || '').trim();

    if (!displayName) {
      return res.status(400).json({ message: 'Display name cannot be empty' });
    }
    if (displayName.length > MAX_DISPLAY_NAME_LENGTH) {
      return res.status(400).json({
        message: `Display name must be ${MAX_DISPLAY_NAME_LENGTH} characters or fewer`,
      });
    }

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(req.userId).select('-avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.displayName = displayName;
    await user.save();

    res.json({ message: 'Display name updated', displayName: user.displayName });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/notification-preference
// @desc    เปิด/ปิดการแจ้งเตือนในแอพทั้งหมด (เควสสำเร็จ / เหรียญปลดล็อก / ของใกล้หมดอายุ)
// ปิดแล้วแค่หยุดสร้างแจ้งเตือนใหม่ — ใบที่มีอยู่แล้วในลิสต์ยังโชว์เหมือนเดิม ไม่ได้ลบทิ้ง
router.post('/notification-preference', authMiddleware, async (req, res) => {
  try {
    const { enabled } = req.body;
    if (typeof enabled !== 'boolean') {
      return res.status(400).json({ message: 'enabled must be a boolean' });
    }

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(req.userId).select('-avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.notificationsEnabled = enabled;
    await user.save();

    res.json({ message: 'Notification preference updated', notificationsEnabled: user.notificationsEnabled });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/upgrade-guest
// @desc    เปลี่ยนบัญชี Guest ให้เป็นบัญชีปกติ (ตั้ง email + password + ชื่อ)
// สำคัญ: ใช้ _id เดิม ไม่ได้สร้าง user ใหม่ — points / XP / ประวัติ quest / ของในตู้เย็น เลยติดมาครบ
// token เดิมก็ยังใช้ได้ต่อ เพราะข้างในเก็บ userId ซึ่งไม่ได้เปลี่ยน
router.post('/upgrade-guest', authMiddleware, async (req, res) => {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(req.userId).select('-avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    if (!user.isGuest) {
      return res.status(400).json({ message: 'This account is already registered' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    const emailTaken = await User.findOne({ email: normalizedEmail });
    if (emailTaken) {
      return res.status(409).json({ message: 'This email is already registered' });
    }

    const salt = await bcrypt.genSalt(10);
    user.email = normalizedEmail;
    user.password = await bcrypt.hash(password, salt);
    user.displayName = (displayName || '').trim() || normalizedEmail.split('@')[0];
    user.isGuest = false;

    try {
      await user.save();
    } catch (err) {
      // กันกรณีมีคนสมัครอีเมลนี้แทรกเข้ามาพอดีระหว่างที่เช็คกับที่บันทึก (unique index จะกันให้อีกชั้น)
      if (err.code === 11000) {
        return res.status(409).json({ message: 'This email is already registered' });
      }
      throw err;
    }

    res.json({
      message: 'Account created',
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

// @route   POST /api/auth/verify-password
// @desc    เช็ครหัสผ่านปัจจุบันว่าถูกไหม — ใช้ก่อนขั้นตอนกรอกรหัสผ่านใหม่ในหน้า Change Password
// (ฝั่ง /change-password ก็ยัง verify ซ้ำอีกชั้นตอนเปลี่ยนจริง ไม่ได้พึ่ง endpoint นี้เป็นการตรวจครั้งเดียว)
router.post('/verify-password', authMiddleware, async (req, res) => {
  try {
    const { password } = req.body;
    if (!password) {
      return res.status(400).json({ message: 'Please enter your password' });
    }

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(req.userId).select('-avatarData');
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

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(req.userId).select('-avatarData');
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

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(decoded.userId).select('-avatarData');
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
