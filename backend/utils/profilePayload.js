// สร้าง progress (level/xp) + streak (Daily Streak) + stats (จำนวนเควส/CO2/ปาร์ตี้) ของ user คนไหนก็ได้
// แยกออกมาจาก GET /auth/me เพื่อให้ GET /users/:id (ดูโปรไฟล์คนอื่น) เอาไปใช้ซ้ำได้
// โดยไม่ต้องก๊อปโค้ด aggregate ซ้ำ — ทั้งสอง route คิดเลขแบบเดียวกันเป๊ะๆ
const User = require('../models/User');
const QuestHistory = require('../models/QuestHistory');
const progression = require('./progression');
const { getDisplayStreak } = require('./streak');

// รับ user document ที่ query มาแล้ว ต้องการ _id, xp, totalQuestsCompleted, streakCount,
// lastStreakDate (ไม่ใช่ userId string เพราะ aggregate ไม่ cast string -> ObjectId ให้เอง
// ใช้ user._id ที่เป็น ObjectId จริงตรงๆ)
async function buildProfileStats(user) {
  // ยิงพร้อมกันทีเดียว ไม่ต้องรอทีละ query
  // liveHistoryCount ใช้แค่ตอน backfill บัญชีเก่า (ดูด้านล่าง) ไม่ใช่ตัวเลขที่โชว์จริงอีกต่อไป
  // เพราะแถวใน QuestHistory ถูกลบได้ (เช่นตอนใช้ไอเทม Super Energy ลบของวันนี้ทิ้งเพื่อทำซ้ำ) —
  // ตัวเลขที่โชว์จริงต้องมาจาก user.totalQuestsCompleted ซึ่งสะสมตลอด ไม่มีทางลดลง
  const [liveHistoryCount, questAgg] = await Promise.all([
    QuestHistory.countDocuments({ userId: user._id }),
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

  // backfill ให้บัญชีเก่าที่มีมาก่อนฟีเจอร์นี้ (totalQuestsCompleted ยังเป็น 0 จาก default ทั้งที่
  // เคยทำเควสมาก่อนแล้วจริงๆ) — เกิดครั้งเดียวต่อบัญชี ครั้งถัดไป totalQuestsCompleted > 0 แล้วจะไม่
  // เข้าเงื่อนไขนี้อีก ไม่ await กันหน้า Profile ต้องรอ (ไม่ใช่ข้อมูลที่ critical ต้องเป๊ะทันที)
  let questCompleted = user.totalQuestsCompleted || 0;
  if (questCompleted === 0 && liveHistoryCount > 0) {
    questCompleted = liveHistoryCount;
    User.updateOne({ _id: user._id }, { $set: { totalQuestsCompleted: liveHistoryCount } }).catch(
      (err) => console.error('backfill totalQuestsCompleted ไม่สำเร็จ:', err.message)
    );
  }

  return {
    progress,
    streak: getDisplayStreak(user),
    stats: { questCompleted, co2SavedKg, partiesJoined },
  };
}

module.exports = { buildProfileStats };
