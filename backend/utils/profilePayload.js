// สร้าง progress (level/xp) + streak (Daily Streak) + stats (จำนวนเควส/CO2/ปาร์ตี้) ของ user คนไหนก็ได้
// แยกออกมาจาก GET /auth/me เพื่อให้ GET /users/:id (ดูโปรไฟล์คนอื่น) เอาไปใช้ซ้ำได้
// โดยไม่ต้องก๊อปโค้ด aggregate ซ้ำ — ทั้งสอง route คิดเลขแบบเดียวกันเป๊ะๆ
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const progression = require('./progression');
const { getDisplayStreak } = require('./streak');

// รับ user document ที่ query มาแล้ว ต้องการ _id, xp, streakCount, lastStreakDate (ไม่ใช่ userId
// string เพราะ aggregate ไม่ cast string -> ObjectId ให้เอง ใช้ user._id ที่เป็น ObjectId จริงตรงๆ)
async function buildProfileStats(user) {
  // ยิงพร้อมกันทีเดียว ไม่ต้องรอทีละ query
  const [questCompleted, questTotal, questAgg] = await Promise.all([
    QuestHistory.countDocuments({ userId: user._id }),
    Quest.countDocuments({ isActive: true }),
    // partiesJoined + co2SavedKg ต้อง join ไปหา Quest เพราะข้อมูลอยู่ที่ template ของ quest
    QuestHistory.aggregate([
      { $match: { userId: user._id } },
      {
        $lookup: {
          from: 'quests',
          localField: 'questId',
          foreignField: '_id',
          as: 'quest',
        },
      },
      { $unwind: '$quest' },
      {
        $group: {
          _id: null,
          partiesJoined: {
            $sum: { $cond: [{ $eq: ['$quest.type', 'party'] }, 1, 0] },
          },
          co2SavedKg: { $sum: { $ifNull: ['$quest.co2SavedKg', 0] } },
        },
      },
    ]),
  ]);

  const { partiesJoined = 0, co2SavedKg = 0 } = questAgg[0] || {};

  // level คิดสดจาก xp เสมอ (xp คือ source of truth ตามดีไซน์)
  const progress = progression.levelProgress(user.xp);

  return {
    progress,
    streak: getDisplayStreak(user),
    stats: { questCompleted, questTotal, co2SavedKg, partiesJoined },
  };
}

module.exports = { buildProfileStats };
