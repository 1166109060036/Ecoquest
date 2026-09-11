const mongoose = require('mongoose');
const Achievement = require('../models/Achievement');
const QuestHistory = require('../models/QuestHistory');
const { notifyAchievementUnlocked } = require('./notifications');

// รวมนิยามเหรียญทั้งหมดไว้ไฟล์เดียว — อยากเพิ่ม/แก้เงื่อนไขปลดล็อกแก้ที่นี่ที่เดียว
// (แนวเดียวกับ progression.js ที่รวมสูตร level/rank ไว้ที่เดียว)
//
// เงื่อนไขตอนนี้: ทำ quest ในหมวดนั้นครบตามจำนวน "required" ครั้ง
// อยากปรับให้ปลดล็อกง่ายขึ้นตอนเดโม ก็ลดเลข required ได้เลย ไม่ต้องแก้โค้ดอื่น
//
// ⚠️ medalType ห้ามเปลี่ยนหลังมีคนปลดล็อกไปแล้ว เพราะเป็นคีย์ที่บันทึกลง DB
//    (มี unique index (userId, medalType) กันปลดล็อกซ้ำอยู่)
const MEDALS = [
  {
    medalType: 'food_saver',
    title: 'Food Saver',
    category: 'food_waste',
    required: 10,
  },
  {
    medalType: 'recycling',
    title: 'Recycling',
    category: 'recycling',
    required: 10,
  },
  {
    medalType: 'plastic_reduction',
    title: 'Plastic Reduction',
    category: 'plastic',
    required: 10,
  },
  {
    // เพิ่มทีหลังตอน seed quest จริง เพราะมีหมวด energy เกิดขึ้นมา
    // ถ้าไม่มีเหรียญนี้ quest หมวดประหยัดพลังงานจะไม่มีรางวัลระยะยาวอะไรเลย
    medalType: 'energy_saver',
    title: 'Energy Saver',
    category: 'energy',
    required: 10,
  },
  {
    // community quest เป็นงานใหญ่ (ลงพื้นที่จริง) เลยตั้งไว้แค่ครั้งเดียว
    // ตอนนี้ยังปลดล็อกไม่ได้เพราะยังไม่มี community quest ที่เปิดใช้งาน (รอระบบ Party)
    medalType: 'community',
    title: 'Community',
    category: 'community',
    required: 1,
  },
];

const describe = (medal) =>
  medal.required === 1
    ? `Complete a ${medal.category.replace('_', ' ')} quest`
    : `Complete ${medal.required} ${medal.category.replace('_', ' ')} quests`;

// นับว่า user ทำ quest สำเร็จไปกี่ครั้งในแต่ละหมวด
// ต้อง join ไปหา Quest เพราะ QuestHistory เก็บแค่ questId ไม่ได้เก็บหมวดไว้ด้วย
const countByCategory = async (userId) => {
  // ⚠️ aggregate ไม่ cast string -> ObjectId ให้อัตโนมัติเหมือน find() ต้องแปลงเอง
  //    ถ้าส่ง req.userId (string) เข้าไปตรงๆ จะ match ไม่เจอเลยและได้ 0 ทุกหมวดแบบเงียบๆ
  const rows = await QuestHistory.aggregate([
    { $match: { userId: new mongoose.Types.ObjectId(String(userId)) } },
    {
      $lookup: {
        from: 'quests',
        localField: 'questId',
        foreignField: '_id',
        as: 'quest',
      },
    },
    { $unwind: '$quest' },
    { $group: { _id: '$quest.category', count: { $sum: 1 } } },
  ]);

  const counts = {};
  for (const row of rows) counts[row._id] = row.count;
  return counts;
};

// สถานะเหรียญทั้งหมดของ user (ปลดล็อกแล้วหรือยัง + ความคืบหน้า)
// คืนเหรียญที่ยังไม่ปลดล็อกมาด้วย เพื่อให้แอพโชว์เป็นช่องล็อกพร้อมความคืบหน้าได้
const getAchievements = async (userId) => {
  const [counts, unlockedRows] = await Promise.all([
    countByCategory(userId),
    Achievement.find({ userId }).select('medalType unlockedAt'),
  ]);

  const unlockedMap = new Map(unlockedRows.map((a) => [a.medalType, a.unlockedAt]));

  return MEDALS.map((medal) => {
    const progress = counts[medal.category] || 0;
    return {
      medalType: medal.medalType,
      title: medal.title,
      description: describe(medal),
      category: medal.category,
      required: medal.required,
      // ตัดไม่ให้เกิน required เพื่อให้ progress bar ฝั่งแอพไม่ล้น
      progress: Math.min(progress, medal.required),
      unlocked: unlockedMap.has(medal.medalType),
      unlockedAt: unlockedMap.get(medal.medalType) || null,
    };
  });
};

// เช็คว่ามีเหรียญไหนเพิ่งเข้าเงื่อนไขบ้าง แล้วบันทึกลง DB
// คืนเฉพาะ "เหรียญที่เพิ่งปลดล็อกรอบนี้" เพื่อให้แอพเอาไปเด้งแจ้งเตือนได้
const syncAchievements = async (userId) => {
  const counts = await countByCategory(userId);
  const already = await Achievement.find({ userId }).select('medalType');
  const alreadySet = new Set(already.map((a) => a.medalType));

  const newlyUnlocked = [];
  for (const medal of MEDALS) {
    if (alreadySet.has(medal.medalType)) continue;
    if ((counts[medal.category] || 0) < medal.required) continue;

    try {
      await Achievement.create({ userId, medalType: medal.medalType });
      const unlocked = {
        medalType: medal.medalType,
        title: medal.title,
        description: describe(medal),
      };
      newlyUnlocked.push(unlocked);
      // ใส่ไว้ที่นี่ที่เดียวเพื่อครอบคลุมทั้ง 2 ทางที่ปลดล็อกเหรียญได้ (quest เดี่ยว + party fan-out)
      // ไม่ทำให้ทั้งฟังก์ชันพังถ้าสร้างแจ้งเตือนไม่สำเร็จ เพราะเหรียญปลดล็อกไปแล้วจริงๆ
      try {
        await notifyAchievementUnlocked(userId, unlocked);
      } catch (notifyErr) {
        console.error('สร้างแจ้งเตือนปลดล็อกเหรียญไม่สำเร็จ:', notifyErr.message);
      }
    } catch (err) {
      // ชนกับ unique index = มีอีก request ปลดล็อกไปพร้อมกันพอดี ไม่ถือว่าพัง
      if (err.code !== 11000) throw err;
    }
  }

  return newlyUnlocked;
};

module.exports = { MEDALS, getAchievements, syncAchievements };
