const jwt = require('jsonwebtoken');
const User = require('../models/User');

// ตรวจ JWT แล้วคืน userId — ใช้ร่วมกันทั้ง authMiddleware (HTTP) และ socket auth (WebSocket)
// ที่เดียวจะได้ไม่ต้องแก้ 2 จุดทุกครั้งที่เปลี่ยน logic การ verify token
// โยน error ต่อถ้า token ไม่ถูกต้อง/หมดอายุ — ผู้เรียกรับผิดชอบ catch เอง (HTTP ตอบ 401,
// socket ปฏิเสธการเชื่อมต่อ)
// token ที่มี purpose (เช่น password_reset จาก /auth/verify-reset-otp) ใช้แทน token ล็อกอินไม่ได้ (13 ต.ค. 2026)
// tv = tokenVersion ตอนออก token — เปลี่ยน/รีเซ็ตรหัสผ่านแล้ว tokenVersion เพิ่ม token เก่าทุกเครื่องใช้ไม่ได้ (25 ต.ค. 2026)
// token ก่อนมีระบบนี้ไม่มี tv = นับเป็น 0
// error ที่ token ผิดจริงมี .auth = true — error อื่น (DB ล่ม) ผู้เรียกตอบ 500 ไม่ใช่ 401 แอพจะได้ไม่ล้าง session ทิ้ง
const authError = (msg) => Object.assign(new Error(msg), { auth: true });

const verifyToken = async (token) => {
  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch (err) {
    throw authError(err.message);
  }
  if (decoded.purpose || !decoded.userId) throw authError('Not a sign-in token');
  if (typeof decoded.userId !== 'string' || !/^[a-f\d]{24}$/i.test(decoded.userId)) throw authError('Bad user id');
  const user = await User.findById(decoded.userId).select('tokenVersion').lean();
  if (!user || (user.tokenVersion || 0) !== (decoded.tv || 0)) throw authError('Token revoked');
  return decoded.userId;
};

module.exports = verifyToken;
