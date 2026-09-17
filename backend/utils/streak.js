// รวม logic ของ Daily Streak ไว้ไฟล์เดียว — แนวเดียวกับ progression.js/upgrades.js
// ทำเควสสำเร็จอย่างน้อย 1 อันต่อวัน (ติดต่อกัน) นับเป็น 1 วัน — พลาด 1 วันรีเซ็ทกลับไปวัน 1 ทันที
// ครบรอบ 30 วันได้รางวัลก้อนใหญ่สุด+ไอเทมพิเศษ แล้ววนกลับไปเริ่มวัน 1 ใหม่
const { startOfToday, todayKey } = require('./questDay');
const InventoryItem = require('../models/InventoryItem');

const STREAK_CYCLE_LENGTH = 30;
const STREAK_REWARDS = {
  7: { points: 100, xp: 50 },
  14: { points: 150, xp: 75 },
  21: { points: 200, xp: 100 },
  30: { points: 400, xp: 200, itemType: 'green_energy', itemQty: 1 },
};

const ONE_DAY_MS = 24 * 60 * 60 * 1000;

// เรียกตอนเควสสำเร็จ (จาก quests.js/party.js/admin.js ก่อน user.save()) — แก้ user ในหน่วยความจำ
// (points/xp/streakCount/lastStreakDate) ให้ caller เป็นคน save() รวมทีเดียวกับการเปลี่ยนแปลงอื่น
// ไม่ query/save ซ้ำ — คืน reward object ถ้าวันนี้ตรง milestone ไม่งั้นคืน null
// ปลอดภัยเรียกซ้ำได้หลายครั้งในวันเดียวกัน (นับแค่ครั้งแรกของวัน ครั้งถัดไป no-op คืน null)
async function applyDailyQuestCompletion(user) {
  const today = startOfToday();

  if (user.lastStreakDate && user.lastStreakDate.getTime() === today.getTime()) {
    return null; // นับไปแล้ววันนี้
  }

  const isConsecutive =
    user.lastStreakDate && today.getTime() - user.lastStreakDate.getTime() === ONE_DAY_MS;

  user.streakCount = isConsecutive ? user.streakCount + 1 : 1;
  user.lastStreakDate = today;

  const reward = STREAK_REWARDS[user.streakCount];
  if (reward) {
    user.points += reward.points;
    user.xp += reward.xp;
    if (reward.itemType) {
      await InventoryItem.findOneAndUpdate(
        { userId: user._id, itemType: reward.itemType },
        { $inc: { quantity: reward.itemQty } },
        { upsert: true }
      );
    }
  }

  const day = user.streakCount;
  if (user.streakCount >= STREAK_CYCLE_LENGTH) {
    user.streakCount = 0; // ครบรอบ 30 วัน รีเซ็ทกลับไปเริ่มวัน 1 ใหม่
  }

  // dateKey (วันที่จริง ไม่ใช่ Date.now()) ให้ dedupeKey ของ notifyStreakMilestone ไม่ชนกันข้ามรอบ
  // 30 วัน (วัน 7 ของรอบที่ 1 กับวัน 7 ของรอบที่ 2 เกิดคนละวันที่จริงเสมอ)
  return reward ? { day, dateKey: todayKey(), ...reward } : null;
}

// ใช้ตอนสร้าง profile payload (อ่านอย่างเดียว ไม่ save) — ถ้า streak ขาดไปแล้วจริงๆ (ไม่ได้เข้ามาทำ
// เควสตามวันที่ควรจะเป็น) ให้โชว์ 0 แม้ค่าใน DB ยังไม่ถูกรีเซ็ทจริง (จะรีเซ็ทจริงตอนทำเควสครั้งถัดไป
// ผ่าน applyDailyQuestCompletion ด้านบน) กัน UI โชว์เลขเก่าที่ตายไปแล้วค้างอยู่
function getDisplayStreak(user) {
  const today = startOfToday();
  const gapMs = user.lastStreakDate ? today.getTime() - user.lastStreakDate.getTime() : Infinity;
  const isAlive = gapMs === 0 || gapMs === ONE_DAY_MS;

  return {
    count: isAlive ? user.streakCount : 0,
    cycleLength: STREAK_CYCLE_LENGTH,
    milestones: Object.keys(STREAK_REWARDS).map(Number),
    // ส่งรายละเอียดรางวัลแต่ละ milestone ไปด้วย ให้แอพโชว์ preview ได้โดยไม่ต้อง hardcode ตัวเลขซ้ำ
    // (สูตร/ตัวเลขจริงมีเจ้าของเดียวคือไฟล์นี้)
    rewards: STREAK_REWARDS,
  };
}

module.exports = { STREAK_CYCLE_LENGTH, STREAK_REWARDS, applyDailyQuestCompletion, getDisplayStreak };
