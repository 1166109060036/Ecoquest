// ⚠️ ตอนนี้ server จัดการเปิด/ปิด season ให้อัตโนมัติแล้ว (ดู backend/utils/seasons.js
// เรียกจาก utils/profilePayload.js ทุกครั้งที่มีคนเรียก GET /auth/me และตอน server boot)
// สคริปต์นี้ **ไม่จำเป็นต้องรันแล้ว** ในการใช้งานปกติ เหลือไว้สำหรับบังคับสร้าง/รีเซ็ต season
// ตอน dev/debug เท่านั้น
//
// รันด้วย: npm run seed:season
//
// ⚠️ ระวัง: สคริปต์นี้ hardcode SEASON_NUMBER = 1 เสมอ ถ้าระบบหมุนไปถึง season 2-3 แล้วมารันสคริปต์นี้
// จะเป็นการ "ทับ" วันที่ของ season 1 ใหม่ (เพราะ upsert อิง seasonNumber) แล้วปิด season ปัจจุบันทิ้ง
// ไม่ใช่การเปิด season ถัดไป — ถ้าจะบังคับข้าม season ให้ไปแก้ที่ DB โดยตรงหรือแก้ SEASON_NUMBER ก่อนรัน
//
// รันซ้ำได้ ไม่สร้างซ้ำ (upsert อิงจาก seasonNumber)
require('dotenv').config();
const mongoose = require('mongoose');
const Season = require('../models/Season');

// ปรับได้ตามใจ — จะให้ season ยาวกี่เดือนก็แก้ตรงนี้
const SEASON_NUMBER = 1;
const DURATION_DAYS = 90;

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('เชื่อม MongoDB Atlas สำเร็จ');

    const startDate = new Date();
    startDate.setHours(0, 0, 0, 0);
    const endDate = new Date(startDate.getTime() + DURATION_DAYS * 24 * 60 * 60 * 1000);

    // ควรมี season ที่ active แค่อันเดียว — ปิดอันอื่นก่อนเสมอ
    await Season.updateMany({ seasonNumber: { $ne: SEASON_NUMBER } }, { isActive: false });

    const season = await Season.findOneAndUpdate(
      { seasonNumber: SEASON_NUMBER },
      { seasonNumber: SEASON_NUMBER, startDate, endDate, isActive: true },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    console.log(
      `✔ Season ${season.seasonNumber} เปิดใช้งานแล้ว\n` +
        `  เริ่ม : ${season.startDate.toISOString()}\n` +
        `  จบ   : ${season.endDate.toISOString()}`
    );
    console.log(`\nจำนวน season ที่ active ตอนนี้: ${await Season.countDocuments({ isActive: true })}`);
  } catch (err) {
    console.error('seed ไม่สำเร็จ:', err.message);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
})();
