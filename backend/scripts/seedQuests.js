// สคริปต์ seed quest ตั้งต้นลง MongoDB
// รันด้วย: npm run seed:quests   (หรือ node scripts/seedQuests.js)
//
// เขียนแบบ upsert (อิงจาก title) — รันซ้ำได้ไม่สร้างของซ้ำ แค่อัปเดตค่าให้ตรงกับในไฟล์นี้
require('dotenv').config();
const mongoose = require('mongoose');
const Quest = require('../models/Quest');

const QUESTS = [
  {
    title: 'Check Your Food & Expiration Dates',
    description: 'Food Waste Quest',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    // ⚠️ ค่าประมาณ ยังไม่ได้อ้างอิงงานวิจัยจริง — ปรับได้ตามข้อมูลที่หามาทีหลัง
    co2SavedKg: 0.2,
    isDaily: true,
    // ต้องบันทึกของในตู้เย็นวันนี้ก่อน ถึงจะกดสำเร็จได้ (กดปุ่มเฉยๆ ไม่ให้คะแนน)
    actionKey: 'fridge_check',
  },
];

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('เชื่อม MongoDB Atlas สำเร็จ');

    for (const q of QUESTS) {
      // scorePoints คำนวณจาก difficulty + impact เสมอ ห้ามกรอกมือ (easy+low = 5+5 = 10)
      const scorePoints = Quest.calculateScore(q.difficulty, q.impact);

      const saved = await Quest.findOneAndUpdate(
        { title: q.title },
        { ...q, scorePoints, isActive: true },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );

      console.log(
        `✔ ${saved.title}  [${saved.difficulty}+${saved.impact}] ` +
          `= ${saved.scorePoints} points / ${saved.xpReward} XP` +
          (saved.isDaily ? ' (วันละครั้ง)' : '')
      );
    }

    const total = await Quest.countDocuments({ isActive: true });
    console.log(`\nตอนนี้มี quest ที่เปิดใช้งานอยู่ทั้งหมด ${total} อัน`);
  } catch (err) {
    console.error('seed ไม่สำเร็จ:', err.message);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
})();
