const jwt = require('jsonwebtoken');

// ตรวจ JWT แล้วคืน userId — ใช้ร่วมกันทั้ง authMiddleware (HTTP) และ socket auth (WebSocket)
// ที่เดียวจะได้ไม่ต้องแก้ 2 จุดทุกครั้งที่เปลี่ยน logic การ verify token
// โยน error ต่อถ้า token ไม่ถูกต้อง/หมดอายุ — ผู้เรียกรับผิดชอบ catch เอง (HTTP ตอบ 401,
// socket ปฏิเสธการเชื่อมต่อ)
const verifyToken = (token) => {
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  return decoded.userId;
};

module.exports = verifyToken;
