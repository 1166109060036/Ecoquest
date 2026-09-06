const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const { sendOtpEmail } = require('../utils/mailer');

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
      return res.status(400).json({ message: 'กรุณากรอก email และ password' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'password ต้องมีอย่างน้อย 6 ตัวอักษร' });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ message: 'อีเมลนี้ถูกใช้งานแล้ว' });
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
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

// @route   POST /api/auth/login
// @desc    เข้าสู่ระบบด้วย email + password
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'กรุณากรอก email และ password' });
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user) {
      return res.status(401).json({ message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
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
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
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
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

// @route   GET /api/auth/me
// @desc    ดึงข้อมูล user ปัจจุบันจาก token (ใช้ตอนเปิดแอพเพื่อเช็ค session)
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'ไม่พบผู้ใช้งาน' });
    }
    res.json({ user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

// @route   POST /api/auth/verify-password
// @desc    เช็ครหัสผ่านปัจจุบันว่าถูกไหม — ใช้ก่อนขั้นตอนกรอกรหัสผ่านใหม่ในหน้า Change Password
// (ฝั่ง /change-password ก็ยัง verify ซ้ำอีกชั้นตอนเปลี่ยนจริง ไม่ได้พึ่ง endpoint นี้เป็นการตรวจครั้งเดียว)
router.post('/verify-password', authMiddleware, async (req, res) => {
  try {
    const { password } = req.body;
    if (!password) {
      return res.status(400).json({ message: 'กรุณากรอกรหัสผ่าน' });
    }

    const user = await User.findById(req.userId);
    if (!user || user.isGuest) {
      return res.status(400).json({ message: 'บัญชี Guest ไม่มีรหัสผ่าน' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'รหัสผ่านไม่ถูกต้อง' });
    }

    res.json({ message: 'รหัสผ่านถูกต้อง' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

// @route   POST /api/auth/change-password
// @desc    เปลี่ยนรหัสผ่าน (ต้อง login อยู่แล้ว + รู้รหัสผ่านเดิม)
router.post('/change-password', authMiddleware, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'กรุณากรอกรหัสผ่านเดิมและรหัสผ่านใหม่' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร' });
    }

    const user = await User.findById(req.userId);
    if (!user || user.isGuest) {
      return res.status(400).json({ message: 'บัญชี Guest ไม่มีรหัสผ่านให้เปลี่ยน' });
    }

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'รหัสผ่านเดิมไม่ถูกต้อง' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.json({ message: 'เปลี่ยนรหัสผ่านสำเร็จ' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    ขอ OTP ไปยังอีเมล เพื่อใช้ตั้งรหัสผ่านใหม่ (ลืมรหัสผ่าน)
router.post('/forgot-password', async (req, res) => {
  // ตอบข้อความเดียวกันเสมอไม่ว่าจะเจออีเมลนี้ในระบบหรือไม่ กันคนเดารายชื่ออีเมลที่สมัครไว้
  const genericResponse = { message: 'ถ้าอีเมลนี้มีอยู่ในระบบ เราได้ส่ง OTP ไปให้แล้ว' };

  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ message: 'กรุณากรอกอีเมล' });
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
    res.status(500).json({ message: 'ส่ง OTP ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง' });
  }
});

// @route   POST /api/auth/verify-reset-otp
// @desc    ยืนยัน OTP ที่ได้รับทางอีเมล แลกเป็น reset token อายุสั้นไว้ตั้งรหัสผ่านใหม่
router.post('/verify-reset-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ message: 'กรุณากรอกอีเมลและ OTP' });
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user || !user.resetOtpHash || !user.resetOtpExpires || user.resetOtpExpires < new Date()) {
      return res.status(400).json({ message: 'OTP ไม่ถูกต้องหรือหมดอายุ' });
    }

    const isMatch = await bcrypt.compare(otp, user.resetOtpHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'OTP ไม่ถูกต้องหรือหมดอายุ' });
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
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

// @route   POST /api/auth/reset-password
// @desc    ตั้งรหัสผ่านใหม่ด้วย reset token ที่ได้จาก /verify-reset-otp
router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword } = req.body;
    if (!resetToken || !newPassword) {
      return res.status(400).json({ message: 'ข้อมูลไม่ครบถ้วน' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร' });
    }

    let decoded;
    try {
      decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
    } catch (err) {
      return res.status(401).json({ message: 'คำขอเปลี่ยนรหัสผ่านหมดอายุ กรุณาขอ OTP ใหม่' });
    }

    if (decoded.purpose !== 'password_reset') {
      return res.status(401).json({ message: 'token ไม่ถูกต้อง' });
    }

    const user = await User.findById(decoded.userId);
    if (!user) {
      return res.status(404).json({ message: 'ไม่พบผู้ใช้งาน' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.json({ message: 'ตั้งรหัสผ่านใหม่สำเร็จ' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์' });
  }
});

module.exports = router;
