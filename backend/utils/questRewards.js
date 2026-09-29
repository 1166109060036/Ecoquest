// ให้รางวัลการทำเควสสำเร็จ 1 ครั้ง — ที่เดียวทั้งระบบ แยกออกมาจาก routes/quests.js /complete และ
// routes/party.js /complete เดิม (28 ก.ย. 2026) เพราะตอนนี้มี 2 ทางที่ได้รางวัล:
//   1. ทันที — เควสที่ระบบตรวจเองได้ (Check Food ต้องมีของในตู้เย็นใหม่)
//   2. ตอนหลักฐานผ่านการตรวจ — utils/submissions.js#finalizeSubmission
// ทั้งสองทางต้องคิดเลขเหมือนกันเป๊ะ (bonus, level, ยอดรวม, เหรียญ) เลยห้ามมีโค้ดให้รางวัลแยกสองชุด
const QuestHistory = require('../models/QuestHistory');
const User = require('../models/User');
const progression = require('./progression');
const { syncAchievements } = require('./achievements');
const { notifyStreakMilestone } = require('./notifications');
const { getUserBonuses, applyBonuses } = require('./upgrades');
const { withEnergyBoosts } = require('./inventory');
const { applyDailyQuestCompletion } = require('./streak');

// นับ Daily Streak ของวันนี้ให้ user (mutate + save เอง) — แยกออกมาเพราะเควสที่ต้องตรวจนับ streak ตั้งแต่ตอนส่ง
// ไม่ใช่ตอนผ่าน (ผ่านอาจข้ามไปวันถัดไป streak จะขาดทั้งที่ทำกิจกรรมวันนั้นจริง)
const applyStreakNow = async (user) => {
  const streakMilestone = await applyDailyQuestCompletion(user);
  await user.save();
  if (streakMilestone) {
    try {
      await notifyStreakMilestone(user._id, streakMilestone.day, streakMilestone);
    } catch (notifyErr) {
      console.error('สร้างแจ้งเตือน streak ไม่สำเร็จ:', notifyErr.message);
    }
  }
  return streakMilestone;
};

// ให้รางวัล 1 ครั้ง: QuestHistory + points/xp/level + ยอดรวมตลอดชีพ + (streak) + เหรียญ
// completedAt = เวลาที่ทำจริง (ส่งหลักฐาน) ไม่ใช่เวลาที่ตรวจผ่าน — ประวัติ/CO2 รายวันจะได้ลงวันที่ถูก
// applyStreak: true เฉพาะทางที่ 1 (ทางที่ 2 นับ streak ไปแล้วตอนส่ง)
// แจ้งเตือน "ทำเควสสำเร็จ/ผ่าน" ให้ผู้เรียกส่งเอง (dedupeKey คนละแบบ) — ที่นี่แจ้งแค่ streak/เหรียญ
// คืน null ถ้าไม่มี user แล้ว (ถูกลบไป)
const awardQuest = async (userId, quest, { completedAt = new Date(), applyStreak = false } = {}) => {
  // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาทุกครั้งที่ให้รางวัลโดยไม่ได้ใช้
  const user = await User.findById(userId).select('-avatarData');
  if (!user) return null;

  // คำนวณครั้งเดียวแล้วใช้ค่าเดิมทุกจุด (ประวัติ, ยอดผู้ใช้, response, แจ้งเตือน) ไม่งั้นตัวเลขไม่ตรงกัน
  // withEnergyBoosts เติมตัวคูณจากไอเทม Energy ที่ยังไม่หมดอายุ (ร้านปิดแล้วแต่บัฟที่ใช้ไปก่อนหน้ายังนับจนหมดเวลา)
  const bonuses = withEnergyBoosts(await getUserBonuses(user._id), user);
  const reward = applyBonuses(bonuses, quest);

  const history = await QuestHistory.create({
    userId: user._id,
    questId: quest._id,
    pointsEarned: reward.points,
    xpEarned: reward.xp,
    completedAt,
  });

  user.points += reward.points;
  user.xp += reward.xp;
  // level เป็น cache ของ xp — คำนวณใหม่ทุกครั้งที่ xp เปลี่ยน
  user.level = progression.levelFromXp(user.xp);
  // ยอดรวมตลอดชีพ +1 เสมอ ไม่มีทางลดลง (ต่างจาก QuestHistory ที่ลบแถวได้ตอนใช้ Super Energy)
  user.totalQuestsCompleted = (user.totalQuestsCompleted || 0) + 1;

  let streakMilestone = null;
  if (applyStreak) {
    streakMilestone = await applyStreakNow(user); // save รวมในนี้แล้ว
  } else {
    await user.save();
  }

  // เช็คเหรียญหลังบันทึกประวัติแล้ว — quest ที่เพิ่งทำต้องถูกนับด้วย
  const newAchievements = await syncAchievements(user._id);

  return { user, reward, history, newAchievements, streakMilestone };
};

module.exports = { awardQuest, applyStreakNow };
