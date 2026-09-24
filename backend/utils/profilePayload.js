// สร้าง progress (level/xp) + streak (Daily Streak) + stats (จำนวนเควส/CO2/ปาร์ตี้) ของ user คนไหนก็ได้
// แยกออกมาจาก GET /auth/me เพื่อให้ GET /users/:id (ดูโปรไฟล์คนอื่น) เอาไปใช้ซ้ำได้
// โดยไม่ต้องก๊อปโค้ด aggregate ซ้ำ — ทั้งสอง route คิดเลขแบบเดียวกันเป๊ะๆ
const User = require('../models/User');
const QuestHistory = require('../models/QuestHistory');
const progression = require('./progression');
const { getDisplayStreak } = require('./streak');
const { QUEST_DAY_UTC_OFFSET_HOURS } = require('./questDay');

// เพดาน kgCO2e ต่อวันของแต่ละ Quest.overlapGroup — กันนับผลกระทบชุดเดียวกันซ้ำ (ดู CO2_RESEARCH.md §6)
// เท่ากับค่าสูงสุดที่เป็นไปได้จริงในหนึ่งวัน:
//   food_waste         = food loss ครัวเรือนเฉลี่ยต่อคนต่อวันทั้งหมด (= Food Saver — 1 Day)
//   single_use_plastic = ค่าของ "Avoid Single-Use Plastic for One Day"
const OVERLAP_DAILY_CAP_KG = {
  food_waste: 0.12,
  single_use_plastic: 0.12,
};

// "+09:00" จาก QUEST_DAY_UTC_OFFSET_HOURS — ตัดวันแบบเดียวกับที่เควสรายวันใช้ ($dateToString รับรูปแบบนี้)
const questDayTimezone = (() => {
  const h = QUEST_DAY_UTC_OFFSET_HOURS;
  const abs = Math.abs(h);
  const hh = String(Math.floor(abs)).padStart(2, '0');
  const mm = String(Math.round((abs % 1) * 60)).padStart(2, '0');
  return `${h < 0 ? '-' : '+'}${hh}:${mm}`;
})();

// รวม co2eEstimateKg ของประวัติเควสทั้งหมด: แถวที่อยู่ overlapGroup เดียวกันในวันเดียวกันรวมกันแล้ว
// ตัดที่เพดานของกลุ่ม ส่วนแถวที่ไม่มีกลุ่มนับเต็มทุกแถว (_id ของแถวเองเป็น "กลุ่ม" ของมัน = ไม่ถูกตัด)
// เควสที่ co2eEstimateKg เป็น null นับเป็น 0
const co2AndPartiesPipeline = (userId) => [
  { $match: { userId } },
  { $lookup: { from: 'quests', localField: 'questId', foreignField: '_id', as: 'quest' } },
  { $unwind: '$quest' },
  {
    $project: {
      isParty: { $eq: ['$quest.type', 'party'] },
      co2: { $ifNull: ['$quest.co2eEstimateKg', 0] },
      overlapGroup: '$quest.overlapGroup',
      day: { $dateToString: { format: '%Y-%m-%d', date: '$completedAt', timezone: questDayTimezone } },
    },
  },
  {
    $group: {
      _id: { day: '$day', bucket: { $ifNull: ['$overlapGroup', '$_id'] } },
      co2: { $sum: '$co2' },
      parties: { $sum: { $cond: ['$isParty', 1, 0] } },
    },
  },
  {
    $project: {
      parties: 1,
      co2: {
        $switch: {
          branches: Object.entries(OVERLAP_DAILY_CAP_KG).map(([group, cap]) => ({
            case: { $eq: ['$_id.bucket', group] },
            then: { $min: ['$co2', cap] },
          })),
          default: '$co2',
        },
      },
    },
  },
  { $group: { _id: null, co2eEstimateKg: { $sum: '$co2' }, partiesJoined: { $sum: '$parties' } } },
];

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
    // partiesJoined + co2eEstimateKg ต้อง join ไปหา Quest เพราะข้อมูลอยู่ที่ template ของ quest
    // (ค่า CO2 อ่านจาก template ปัจจุบันเสมอ — แก้ตัวเลขใน seed แล้วยอดรวมย้อนหลังเปลี่ยนตามทันที)
    QuestHistory.aggregate(co2AndPartiesPipeline(user._id)),
  ]);

  const { partiesJoined = 0, co2eEstimateKg: rawCo2 = 0 } = questAgg[0] || {};
  // ปัดทศนิยมกันเศษ floating point แบบ 0.30000000000000004 หลุดไปถึงแอพ
  const co2eEstimateKg = Math.round(rawCo2 * 1000) / 1000;

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
    stats: { questCompleted, co2eEstimateKg, partiesJoined },
  };
}

module.exports = { buildProfileStats };
