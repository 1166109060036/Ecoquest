const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const { sendOtpEmail } = require('../utils/mailer');
const { buildProfileStats } = require('../utils/profilePayload');
const { avatarUrlFor, cosmeticsFor } = require('../utils/avatar');
const { adminEmails, isAllowlistedAdmin, ADMIN_SESSION_TTL } = require('../middleware/admin');
const { issueOtp, checkOtp, otpSendBlocked } = require('../utils/otp');
const { decodeImage } = require('../utils/imageUpload');
const { limiter, limitBy, tooMany, byIp, byUser } = require('../utils/rateLimit');
const { sweepQuietly } = require('../utils/submissions');

const router = express.Router();

const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '30d' });
};

// ---- จำกัดจำนวนครั้ง (utils/rateLimit.js) — ค่าเผื่อไว้กว้างพอสำหรับ wifi มหาลัยที่หลายคนใช้ IP เดียวกัน ----
const loginFails = limiter('login-fail', { windowMs: 15 * 60 * 1000, max: 10 }); // ล็อกอินผิด ต่อ IP+อีเมล
const limitLoginIp = limitBy('login-ip', { windowMs: 15 * 60 * 1000, max: 60 }, byIp);
const limitRegister = limitBy('register', { windowMs: 60 * 60 * 1000, max: 10 }, byIp);
const limitGuest = limitBy('guest', { windowMs: 60 * 60 * 1000, max: 20 }, byIp,
  'Too many guest accounts from this network. Please try again later');
const limitOtpIp = limitBy('otp-ip', { windowMs: 15 * 60 * 1000, max: 30 }, byIp);
const limitAvatar = limitBy('avatar', { windowMs: 60 * 60 * 1000, max: 20 }, byUser);

// email/password ต้องเป็น string — ส่ง object/array มา (เช่น { "$gt": "" }) ตอบ 400 แทนพังเป็น 500
const isText = (v) => typeof v === 'string' && v.length > 0 && v.length <= 200;

// @route   POST /api/auth/register
// @desc    สมัครสมาชิกด้วย email + password — ยังไม่ให้ token จนกว่าจะยืนยัน OTP ที่ส่งไปทางอีเมล
//          (POST /verify-email) กันสมัครด้วยอีเมลคนอื่น/อีเมลมั่ว
router.post('/register', limitRegister, async (req, res) => {
  try {
    const { email, password, displayName } = req.body;

    if (!isText(email) || !isText(password)) {
      return res.status(400).json({ message: 'Email and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    // เจอบัญชีที่ยังไม่ยืนยัน = สมัครค้างไว้ (ไม่เคยได้ token) -> เขียนทับด้วยข้อมูลใหม่ได้เลย
    // ไม่งั้นใครพิมพ์อีเมลคนอื่นสมัครทิ้งไว้ เจ้าของอีเมลจริงจะสมัครไม่ได้อีก
    let user = await User.findOne({ email: normalizedEmail });
    if (user && user.emailVerified !== false) {
      return res.status(409).json({ message: 'This email is already registered' });
    }
    if (otpSendBlocked(res, normalizedEmail)) return;

    const salt = await bcrypt.genSalt(10);
    if (!user) user = new User({ email: normalizedEmail, isGuest: false, emailVerified: false });
    user.password = await bcrypt.hash(password, salt);
    user.displayName = displayName || normalizedEmail.split('@')[0];
    const otp = await issueOtp(user, 'verify');

    try {
      await user.save();
    } catch (err) {
      if (err.code === 11000) {
        return res.status(409).json({ message: 'This email is already registered' });
      }
      throw err;
    }

    await sendOtpEmail(user.email, otp, 'verify');

    res.status(201).json({ needsVerification: true, email: user.email });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/login
// @desc    เข้าสู่ระบบด้วย email + password
router.post('/login', limitLoginIp, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!isText(email) || !isText(password)) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    // ล็อกอินผิดซ้ำๆ กับอีเมลเดียวกันจาก IP เดียวกัน = พักไว้ก่อน (กันเดารหัสผ่าน)
    const failKey = `${req.ip}|${email.toLowerCase()}`;
    if (loginFails.blocked(failKey)) {
      return tooMany(res, loginFails.retryAfter(failKey), 'Too many failed sign-in attempts. Please try again in a few minutes');
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user) {
      loginFails.hit(failKey);
      return res.status(401).json({ message: 'Incorrect email or password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      loginFails.hit(failKey);
      return res.status(401).json({ message: 'Incorrect email or password' });
    }
    loginFails.reset(failKey);

    // รหัสผ่านถูกแต่ยังไม่ยืนยันอีเมล — แอพเอา needsVerification ไปเปิดหน้ากรอก OTP ต่อ
    if (user.emailVerified === false) {
      return res.status(403).json({
        message: 'Please verify your email first',
        needsVerification: true,
        email: user.email,
      });
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
router.post('/guest', limitGuest, async (req, res) => {
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
// @desc    ดึงข้อมูล user ปัจจุบัน + ความคืบหน้า (level/xp) + Daily Streak + สถิติ สำหรับหน้า Profile/Home
router.get('/me', authMiddleware, async (req, res) => {
  try {
    // ตัดสินหลักฐานภารกิจที่ค้างเกิน 48 ชม. ก่อน (lazy — ไม่มี scheduler) ให้แต้ม/สถิติที่ตอบกลับเป็นค่าล่าสุด
    await sweepQuietly();
    // -avatarData กัน Buffer รูปโปรไฟล์ (อาจหนักหลายร้อย KB) ถูกดึงมาด้วยทั้งที่ route นี้
    // ไม่ได้ใช้ตัวไฟล์เลย ใช้แค่ avatarContentType/avatarUpdatedAt ไปสร้าง avatarUrl พอ
    const user = await User.findById(req.userId).select('-password -avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // progress (level/xp) + streak (Daily Streak) + stats (จำนวนเควส/CO2/ปาร์ตี้) ใช้ตัวช่วยร่วมกับ
    // GET /users/:id (ดูโปรไฟล์คนอื่น) เพื่อให้คิดเลขแบบเดียวกันเป๊ะๆ
    const { progress, streak, stats } = await buildProfileStats(user);

    res.json({
      user: {
        id: user._id,
        email: user.email,
        displayName: user.displayName,
        isGuest: user.isGuest,
        avatarUrl: avatarUrlFor(user),
        cosmetics: cosmeticsFor(user),
        level: progress.level,
        xp: user.xp,
        points: user.points,
        notificationsEnabled: user.notificationsEnabled,
        // true เฉพาะบัญชีจริง (มี email) ที่อยู่ใน ADMIN_EMAILS — ใช้ตัดสินใจโชว์เมนู "Admin Tools"
        // ในหน้า Settings ฝั่งแอพ ไม่ใช่ตัวเช็คสิทธิ์จริง (backend เช็คซ้ำเองทุก route ผ่าน adminMiddleware)
        isAdmin: Boolean(user.email) && adminEmails().includes(user.email.toLowerCase()),
        // บัญชีองค์กร (routes/org.js) — แอพใช้ตัดสินใจโชว์เมนู "My Events" / ปุ่มสมัคร
        organization: {
          status: user.organization?.status || 'none',
          name: user.organization?.name || '',
        },
      },
      progress,
      streak,
      stats,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// กันไฟล์ใหญ่ผิดปกติ (image_picker ฝั่งแอพย่อเหลือด้านยาวสุด 512px quality 75 อยู่แล้ว ~30-60KB)
const MAX_AVATAR_BYTES = 2 * 1024 * 1024;

// @route   POST /api/auth/avatar
// @desc    ตั้ง/ลบรูปโปรไฟล์จริง — ส่ง { avatarBase64, contentType } มาเพื่อตั้ง
//          หรือส่ง { avatarBase64: null } มาเพื่อลบ
// เก็บไฟล์เป็น Buffer ในเอกสาร User ตรงๆ (ไม่ใช้ cloud storage แยก ไม่ต้องพึ่ง
// credential/บริการภายนอกเพิ่ม) เสิร์ฟกลับผ่าน GET /api/users/:id/avatar
router.post('/avatar', authMiddleware, limitAvatar, async (req, res) => {
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

    let image;
    try {
      image = decodeImage(avatarBase64, contentType, MAX_AVATAR_BYTES);
    } catch (err) {
      const message = err.message === 'Image is too large' ? 'Avatar image is too large' : 'Invalid avatar data';
      return res.status(err.status || 400).json({ message });
    }

    user.avatarData = image.data;
    user.avatarContentType = image.contentType;
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

// @route   POST /api/auth/upgrade-guest/send-otp
// @desc    ขั้นแรกของ upgrade guest — ส่ง OTP ไปที่อีเมลที่จะใช้ (ต้องยืนยันก่อน /upgrade-guest เหมือนสมัครปกติ)
router.post('/upgrade-guest/send-otp', authMiddleware, limitOtpIp, async (req, res) => {
  try {
    const { email } = req.body;
    if (!isText(email)) {
      return res.status(400).json({ message: 'Email is required' });
    }

    const user = await User.findById(req.userId).select('-avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    if (!user.isGuest) {
      return res.status(400).json({ message: 'This account is already registered' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const emailTaken = await User.findOne({ email: normalizedEmail });
    if (emailTaken && emailTaken.emailVerified !== false) {
      return res.status(409).json({ message: 'This email is already registered' });
    }
    if (otpSendBlocked(res, normalizedEmail)) return;

    user.pendingEmail = normalizedEmail;
    const otp = await issueOtp(user, 'verify');
    await user.save();
    await sendOtpEmail(normalizedEmail, otp, 'verify');

    res.json({ message: 'We have sent a code to your email' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to send OTP. Please try again' });
  }
});

// @route   POST /api/auth/upgrade-guest
// @desc    เปลี่ยนบัญชี Guest ให้เป็นบัญชีปกติ (ตั้ง email + password + ชื่อ)
// สำคัญ: ใช้ _id เดิม ไม่ได้สร้าง user ใหม่ — points / XP / ประวัติ quest / ของในตู้เย็น เลยติดมาครบ
// token เดิมก็ยังใช้ได้ต่อ เพราะข้างในเก็บ userId ซึ่งไม่ได้เปลี่ยน
router.post('/upgrade-guest', authMiddleware, async (req, res) => {
  try {
    const { email, password, displayName, otp } = req.body;

    if (!isText(email) || !isText(password)) {
      return res.status(400).json({ message: 'Email and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }
    if (!isText(String(otp ?? ''))) {
      return res.status(400).json({ message: 'Please enter the code we sent to your email' });
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
    if (emailTaken && emailTaken.emailVerified !== false) {
      return res.status(409).json({ message: 'This email is already registered' });
    }

    // OTP ต้องเป็นของอีเมลเดียวกับที่ขอไว้ใน /upgrade-guest/send-otp
    if (user.pendingEmail !== normalizedEmail) {
      return res.status(400).json({ message: 'Please request a code for this email first' });
    }
    const otpError = await checkOtp(user, 'verify', otp);
    if (otpError) {
      return res.status(400).json({ message: otpError });
    }
    // บัญชีสมัครค้างที่ยังไม่ยืนยันอีเมลนี้ (ไม่เคยได้ token ไม่มีความคืบหน้า) — ลบทิ้งให้ guest ใช้อีเมลนี้แทน
    if (emailTaken) await emailTaken.deleteOne();

    const salt = await bcrypt.genSalt(10);
    user.pendingEmail = null;
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
    if (!isText(password)) {
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

    if (!isText(oldPassword) || !isText(newPassword)) {
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

// @route   POST /api/auth/resend-verification
// @desc    ขอ OTP ยืนยันอีเมลใหม่ (OTP หมดอายุ / มาจากหน้า login ของบัญชีที่ยังไม่ยืนยัน)
router.post('/resend-verification', limitOtpIp, async (req, res) => {
  // ตอบเหมือนกันทุกกรณีเหมือน /forgot-password — ไม่บอกใบ้ว่าอีเมลนี้สมัครค้างไว้ไหม
  const genericResponse = { message: 'If this email is waiting for verification, we have sent a code to it' };
  try {
    const { email } = req.body;
    if (!isText(email)) {
      return res.status(400).json({ message: 'Email is required' });
    }

    const emailKey = email.toLowerCase().trim();
    if (otpSendBlocked(res, emailKey)) return;

    const user = await User.findOne({ email: emailKey, isGuest: false, emailVerified: false });
    if (!user) {
      return res.json(genericResponse);
    }

    const otp = await issueOtp(user, 'verify');
    await user.save();
    await sendOtpEmail(user.email, otp, 'verify');

    res.json(genericResponse);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to send OTP. Please try again' });
  }
});

// @route   POST /api/auth/verify-email
// @desc    ยืนยัน OTP ที่ส่งไปตอนสมัคร — ผ่านแล้วได้ token เข้าแอพเหมือน login
router.post('/verify-email', limitOtpIp, async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!isText(email) || !isText(String(otp ?? ''))) {
      return res.status(400).json({ message: 'Email and OTP are required' });
    }

    const user = await User.findOne({ email: email.toLowerCase().trim(), isGuest: false, emailVerified: false });
    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }
    const otpError = await checkOtp(user, 'verify', otp);
    if (otpError) {
      return res.status(400).json({ message: otpError });
    }

    user.emailVerified = true;
    await user.save();

    res.json({
      token: generateToken(user._id),
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

// @route   POST /api/auth/admin-otp/send
// @desc    Admin 2FA ขั้นแรก — ส่ง OTP ไปที่อีเมลของแอดมินเอง (ดู middleware/admin.js)
router.post('/admin-otp/send', authMiddleware, limitOtpIp, async (req, res) => {
  try {
    if (!(await isAllowlistedAdmin(req.userId))) {
      return res.status(403).json({ message: 'Admin access required' });
    }
    const user = await User.findById(req.userId).select('-avatarData');
    if (otpSendBlocked(res, user.email)) return;

    const otp = await issueOtp(user, 'verify');
    await user.save();
    await sendOtpEmail(user.email, otp, 'admin');

    res.json({ message: 'We have sent a code to your email', email: user.email });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to send OTP. Please try again' });
  }
});

// @route   POST /api/auth/admin-otp/verify
// @desc    Admin 2FA — OTP ถูก = ได้ adminToken (แนบใน header X-Admin-Token) ใช้สิทธิ์แอดมินได้ ADMIN_SESSION_TTL
router.post('/admin-otp/verify', authMiddleware, limitOtpIp, async (req, res) => {
  try {
    const { otp } = req.body;
    if (!isText(String(otp ?? ''))) {
      return res.status(400).json({ message: 'Please enter the code we sent to your email' });
    }
    if (!(await isAllowlistedAdmin(req.userId))) {
      return res.status(403).json({ message: 'Admin access required' });
    }
    const user = await User.findById(req.userId).select('-avatarData');
    const otpError = await checkOtp(user, 'verify', otp);
    if (otpError) {
      return res.status(400).json({ message: otpError });
    }
    await user.save();

    const adminToken = jwt.sign(
      { userId: user._id, purpose: 'admin_2fa' },
      process.env.JWT_SECRET,
      { expiresIn: ADMIN_SESSION_TTL }
    );
    res.json({ adminToken });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    ขอ OTP ไปยังอีเมล เพื่อใช้ตั้งรหัสผ่านใหม่ (ลืมรหัสผ่าน)
router.post('/forgot-password', limitOtpIp, async (req, res) => {
  // ตอบข้อความเดียวกันเสมอไม่ว่าจะเจออีเมลนี้ในระบบหรือไม่ กันคนเดารายชื่ออีเมลที่สมัครไว้
  const genericResponse = { message: 'If this email is registered, we have sent an OTP to it' };

  try {
    const { email } = req.body;
    if (!isText(email)) {
      return res.status(400).json({ message: 'Email is required' });
    }

    // เช็ค rate limit ก่อนค้นหา user ไม่ว่าอีเมลนี้มีจริงไหม (ตอบเหมือนกันทุกกรณี ไม่บอกใบ้ว่าอีเมลนี้สมัครไว้)
    const emailKey = email.toLowerCase().trim();
    if (otpSendBlocked(res, emailKey)) return;

    const user = await User.findOne({ email: emailKey, isGuest: false });
    if (!user) {
      return res.json(genericResponse);
    }

    const otp = await issueOtp(user, 'reset');
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
router.post('/verify-reset-otp', limitOtpIp, async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!isText(email) || !isText(String(otp ?? ''))) {
      return res.status(400).json({ message: 'Email and OTP are required' });
    }

    const user = await User.findOne({ email: email.toLowerCase(), isGuest: false });
    if (!user) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }
    const otpError = await checkOtp(user, 'reset', otp);
    if (otpError) {
      return res.status(400).json({ message: otpError });
    }
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
    // resetToken เป็น JWT ยาว ~210 ตัว เกินเพดาน 200 ของ isText — เช็คแค่เป็นข้อความไม่ยาวผิดปกติ (jwt.verify ตรวจจริงด้านล่าง)
    if (typeof resetToken !== 'string' || !resetToken || resetToken.length > 2000 || !isText(newPassword)) {
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
