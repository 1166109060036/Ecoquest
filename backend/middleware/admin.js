const User = require('../models/User');

// รายชื่ออีเมลแอดมิน — คั่นด้วย , ใน env var เดียว (ไม่มีค่า = ปิดการเข้าถึง admin ทั้งหมดโดย default)
const adminEmails = () =>
  (process.env.ADMIN_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);

// ใช้ต่อจาก authMiddleware เสมอ (ต้องมี req.userId มาก่อนแล้ว) — เช็คว่า email ของ user คนนี้อยู่ใน
// allowlist ไหม บัญชี Guest ไม่มี email เลยเข้าไม่ได้เด็ดขาด ต้องเป็นบัญชีจริงที่ผ่าน /upgrade-guest แล้ว
const adminMiddleware = async (req, res, next) => {
  try {
    const emails = adminEmails();
    if (emails.length === 0) {
      return res.status(403).json({ message: 'Admin access is not configured' });
    }

    const user = await User.findById(req.userId).select('email');
    if (!user?.email || !emails.includes(user.email.toLowerCase())) {
      return res.status(403).json({ message: 'Admin access required' });
    }

    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { adminMiddleware, adminEmails };
