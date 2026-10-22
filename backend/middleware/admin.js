const jwt = require('jsonwebtoken');
const User = require('../models/User');

// รายชื่ออีเมลแอดมิน — คั่นด้วย , ใน env var เดียว (ไม่มีค่า = ปิดการเข้าถึง admin ทั้งหมดโดย default)
const adminEmails = () =>
  (process.env.ADMIN_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);

// อีเมลอยู่ใน allowlist ไหม (ยังไม่ได้เช็ค 2FA) — ใช้แค่ตอนขอ/ยืนยัน OTP แอดมิน (routes/auth.js)
// บัญชี Guest ไม่มี email เลยเข้าไม่ได้เด็ดขาด ต้องเป็นบัญชีจริงที่ผ่าน /upgrade-guest แล้ว
const isAllowlistedAdmin = async (userId) => {
  const emails = adminEmails();
  if (emails.length === 0) return false;
  const user = await User.findById(userId).select('email');
  return Boolean(user?.email) && emails.includes(user.email.toLowerCase());
};

// ---- Admin 2FA (22 ต.ค. 2026 — รับปากอาจารย์) ----
// แค่ login เป็นแอดมินยังใช้สิทธิ์แอดมินไม่ได้ ต้องยืนยัน OTP ทางอีเมลก่อน (POST /api/auth/admin-otp/verify)
// ได้ admin session token อายุสั้น แอพแนบมาใน header X-Admin-Token ทุก request — JWT ขโมยไปอย่างเดียวใช้สิทธิ์แอดมินไม่ได้
// token เก็บในหน่วยความจำแอพ (ปิดแอพ/logout = ต้องยืนยันใหม่) และผูกกับ userId (เอาไปใช้กับบัญชีอื่นไม่ได้)
const ADMIN_SESSION_TTL = '12h';

const hasAdminSession = (req) => {
  const token = req.headers['x-admin-token'];
  if (!token) return false;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return decoded.purpose === 'admin_2fa' && String(decoded.userId) === String(req.userId);
  } catch (err) {
    return false;
  }
};

// ใช้ต่อจาก authMiddleware เสมอ (ต้องมี req.userId มาก่อนแล้ว) — allowlist + ยืนยัน 2FA แล้ว
const adminMiddleware = async (req, res, next) => {
  try {
    if (adminEmails().length === 0) {
      return res.status(403).json({ message: 'Admin access is not configured' });
    }
    if (!(await isAllowlistedAdmin(req.userId))) {
      return res.status(403).json({ message: 'Admin access required' });
    }
    if (!hasAdminSession(req)) {
      return res.status(403).json({ message: 'Please verify the admin code sent to your email', needsAdminOtp: true });
    }

    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// ใช้ในที่ที่ต้องรู้ว่าเป็นแอดมินไหมโดยไม่บล็อก request (เช่นโหวตตรวจภารกิจ — แอดมินโหวตครั้งเดียวตัดสินเลย)
// ยังไม่ยืนยัน 2FA = ถือเป็นผู้เล่นทั่วไป (ไม่เห็นปุ่ม/สิทธิ์แอดมินในฟีด)
const isAdminUser = async (req) => hasAdminSession(req) && isAllowlistedAdmin(req.userId);

module.exports = { adminMiddleware, adminEmails, isAdminUser, isAllowlistedAdmin, ADMIN_SESSION_TTL };
