const mongoose = require('mongoose');

// ใช้กับ router.param('id', idParam) — id ใน URL ผิดรูปแบบ ตอบ 400 แทนที่ findById จะโยน CastError แล้วกลายเป็น 500
const idParam = (req, res, next, id) =>
  mongoose.isObjectIdOrHexString(id) ? next() : res.status(400).json({ message: 'Invalid id' });

module.exports = idParam;
