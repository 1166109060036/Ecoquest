// สร้าง progress (level/xp/rank) + stats (จำนวนเควส/CO2/ปาร์ตี้) ของ user คนไหนก็ได้
// แยกออกมาจาก GET /auth/me เพื่อให้ GET /users/:id (ดูโปรไฟล์คนอื่น) เอาไปใช้ซ้ำได้
// โดยไม่ต้องก๊อปโค้ด aggregate ซ้ำ — ทั้งสอง route คิดเลขแบบเดียวกันเป๊ะๆ
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const Season = require('../models/Season');
const progression = require('./progression');

// รับ user document ที่ query มาแล้ว (ต้องการแค่ _id กับ xp) ไม่ใช่ userId string
// เพราะ aggregate ไม่ cast string -> ObjectId ให้เอง ใช้ user._id ที่เป็น ObjectId จริงตรงๆ ปลอดภัยกว่า
async function buildProfileStats(user) {
  const activeSeason = await Season.findOne({ isActive: true });

  // ยิงพร้อมกันทีเดียว ไม่ต้องรอทีละ query
  const [questCompleted, questTotal, questAgg, seasonAgg] = await Promise.all([
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
    // XP เฉพาะที่ได้ภายใน season ปัจจุบัน — ใช้คิด Rank (ไม่มี season active = ยังไม่เริ่มนับ)
    activeSeason
      ? QuestHistory.aggregate([
          {
            $match: {
              userId: user._id,
              completedAt: { $gte: activeSeason.startDate, $lte: activeSeason.endDate },
            },
          },
          { $group: { _id: null, xp: { $sum: '$xpEarned' } } },
        ])
      : Promise.resolve([]),
  ]);

  const { partiesJoined = 0, co2SavedKg = 0 } = questAgg[0] || {};
  const seasonXp = seasonAgg[0]?.xp || 0;

  // level/rank คิดสดจาก xp เสมอ (xp คือ source of truth ตามดีไซน์)
  const progress = {
    ...progression.levelProgress(user.xp),
    ...progression.rankProgress(seasonXp),
  };

  return {
    progress,
    stats: { questCompleted, questTotal, co2SavedKg, partiesJoined },
  };
}

module.exports = { buildProfileStats };
