// รางวัลเควสหลายวัน (Food Saver 3/7) — ผู้ใช้สั่ง 6 ต.ค. 2026 ให้คนสนใจเควสหลายวันมากกว่าวันเดียว
// เดิม: วันระหว่างทางได้ 0 แต้ม วันสุดท้ายได้แต้มเควสก้อนเดียว → 7 Days = 25 P (3.6 P/วัน) น้อยกว่า 1 Day (15 P/วัน)
//       ทั้งที่ต้องส่งรูปทุกวันและพลาดวันเดียวต้องเริ่มใหม่ — ไม่มีใครอยากทำ (BALANCE_REPORT.md 2 ต.ค. 2026)
// ใหม่: ทุกวันที่เช็คอินผ่านการตรวจได้ CHECK_IN_DAILY + วันสุดท้ายได้โบนัสจบเควส = แต้มเควส × (จำนวนวัน − 1)
//   Food Saver 3 Days (20 P): 12×3 + 40  = 76 P  (~25 P/วัน)
//   Food Saver 7 Days (25 P): 12×7 + 150 = 234 P (~33 P/วัน)   เทียบ 1 Day = 15 P (คอมโบสูงสุด ×1.5 = 22)
// แต้มส่วนใหญ่อยู่ที่โบนัสตอนจบ — ให้อยากทำต่อจนครบ (พลาด = นับวันที่ 1 ใหม่ แต่แต้มรายวันที่ได้ไปแล้วไม่หาย)
// ไม่มีคอมโบ (utils/combo.js นับแค่เควสจบในครั้งเดียว) / upgrade ยังคูณตามปกติ (applyBonuses)
const CHECK_IN_DAILY = { points: 12, xp: 12 };

const days = (quest) => Math.max(1, quest.durationDays || 1);

// โบนัสจบเควส (ยังไม่คูณ upgrade)
const completionBonus = (quest) => ({
  points: (quest.scorePoints || 0) * (days(quest) - 1),
  xp: (quest.xpReward || 0) * (days(quest) - 1),
});

// ฐานรางวัลวันสุดท้าย = รายวัน + โบนัสจบ — ส่งเข้า awardQuest เป็น base แทน scorePoints/xpReward ของเควส
const finalDayBase = (quest) => {
  const bonus = completionBonus(quest);
  return { scorePoints: CHECK_IN_DAILY.points + bonus.points, xpReward: CHECK_IN_DAILY.xp + bonus.xp };
};

// ฐานรางวัลวันระหว่างทาง (รูปแบบเดียวกับ quest ให้ applyBonuses ใช้ได้เลย)
const dailyBase = () => ({ scorePoints: CHECK_IN_DAILY.points, xpReward: CHECK_IN_DAILY.xp });

// ค่าที่แอพโชว์บนการ์ด/หน้ารายละเอียด (ผ่าน applyBonuses ของ user แล้ว ให้ตรงกับที่ได้จริง)
const checkInRewardInfo = (quest, applyBonuses, bonuses) => {
  if (days(quest) <= 1) return null;
  const daily = applyBonuses(bonuses, { type: quest.type, ...dailyBase() });
  const bonusRaw = completionBonus(quest);
  const bonus = applyBonuses(bonuses, { type: quest.type, scorePoints: bonusRaw.points, xpReward: bonusRaw.xp });
  return {
    daily,
    completionBonus: bonus,
    total: { points: daily.points * days(quest) + bonus.points, xp: daily.xp * days(quest) + bonus.xp },
  };
};

module.exports = { CHECK_IN_DAILY, completionBonus, finalDayBase, dailyBase, checkInRewardInfo };
