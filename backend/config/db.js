const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB Atlas');
  } catch (err) {
    console.error('❌ MongoDB connection error:', err.message);
    // 2 สาเหตุที่เจอบ่อยที่สุดตอน deploy ขึ้น cloud — เขียนบอกไว้เลยจะได้ไม่ต้องไล่หานาน
    console.error(
      'ถ้า deploy อยู่บน cloud แล้วขึ้น error นี้ ให้เช็ค:\n' +
        '  1) MongoDB Atlas > Network Access ต้องอนุญาต 0.0.0.0/0 (cloud host ใช้ IP ไม่ตายตัว)\n' +
        '  2) ตั้งค่า env var MONGODB_URI ใน dashboard ของ host แล้วหรือยัง (.env ไม่ได้ถูก push ขึ้น git)'
    );
    process.exit(1);
  }
};

module.exports = connectDB;
