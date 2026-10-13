const jwt = require('jsonwebtoken');

// ตรวจ JWT แล้วคืน userId — ใช้ร่วมกันทั้ง authMiddleware (HTTP) และ socket auth (WebSocket)
// ที่เดียวจะได้ไม่ต้องแก้ 2 จุดทุกครั้งที่เปลี่ยน logic การ verify token
// โยน error ต่อถ้า token ไม่ถูกต้อง/หมดอายุ — ผู้เรียกรับผิดชอบ catch เอง (HTTP ตอบ 401,
// socket ปฏิเสธการเชื่อมต่อ)
// token ที่มี purpose (เช่น password_reset จาก /auth/verify-reset-otp) ใช้แทน token ล็อกอินไม่ได้ (13 ต.ค. 2026)
const verifyToken = (token) => {
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  if (decoded.purpose || !decoded.userId) throw new Error('Not a sign-in token');
  return decoded.userId;
};

module.exports = verifyToken;
