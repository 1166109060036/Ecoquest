// สร้าง Season ให้ระบบ Rank เริ่มทำงาน
// รันด้วย: npm run seed:season
//
// ทำไมต้องมี: Rank คิดจาก "XP ที่ได้ภายใน season ปัจจุบัน" (ดู GET /api/auth/me)
// ถ้าไม่มี season ที่ isActive: true สักอัน seasonXp จะเป็น 0 ตลอด
// แถบ Rank ในหน้า Profile ก็จะค้างที่ Bronze 0/500 ไม่ขยับเลยไม่ว่าจะทำ quest เท่าไหร่
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
