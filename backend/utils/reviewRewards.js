// รางวัลคนตรวจหลักฐานภารกิจ (ผู้ใช้สั่ง 30 ก.ย. 2026) — เดิมตรวจแล้วไม่ได้อะไร คิวเลยค้างนานจนต้องรอแอดมิน
// ได้ทุกครั้งที่โหวตสำเร็จ ไม่ว่าจะกดผ่านหรือไม่ผ่าน (ถ้าให้เฉพาะตอนกดผ่าน = จูงใจให้กดผ่านมั่วๆ)
// จำกัดวันละ REVIEW_REWARD_DAILY_CAP ครั้ง (ตัดวันเที่ยงคืนเวลาญี่ปุ่นแบบเควส) — เกินแล้วยังโหวตได้ แค่ไม่ได้รางวัล
// เรทเทียบ: เควส Easy ได้ 10 P → ตรวจครบเพดาน 10 ครั้ง = 20 P/วัน ไม่แซงการทำเควสจริง
const User = require('../models/User');
const progression = require('./progression');
const { todayKey } = require('./questDay');

const REVIEW_REWARD = { points: 2, xp: 2 };
const REVIEW_REWARD_DAILY_CAP = 10;

// จำนวนที่ได้รางวัลไปแล้ววันนี้ (ฟิลด์เป็นของวันอื่น = 0)
const rewardedToday = (user) => (user?.reviewRewardDay === todayKey() ? user.reviewRewardCount || 0 : 0);

// ให้รางวัล 1 ครั้งแบบ atomic — เงื่อนไขเพดานอยู่ใน query เดียวกับการบวกแต้ม โหวตพร้อมกันหลายใบไม่เกินเพดาน
// คืน { points, xp, rewardedToday } (points/xp = 0 ถ้าเต็มเพดานแล้ว)
const awardReviewer = async (userId) => {
  const day = todayKey();
  const inc = { points: REVIEW_REWARD.points, xp: REVIEW_REWARD.xp };
  const opts = { new: true, projection: { xp: 1, reviewRewardCount: 1, reviewRewardDay: 1 } };
  // วันแรกของวัน (ฟิลด์ยังเป็นวันเก่า) → เริ่มนับ 1 / วันเดียวกันและยังไม่เต็ม → +1
  const user =
    (await User.findOneAndUpdate(
      { _id: userId, reviewRewardDay: { $ne: day } },
      { $set: { reviewRewardDay: day, reviewRewardCount: 1 }, $inc: inc },
      opts
    )) ||
    (await User.findOneAndUpdate(
      { _id: userId, reviewRewardDay: day, reviewRewardCount: { $lt: REVIEW_REWARD_DAILY_CAP } },
      { $inc: { ...inc, reviewRewardCount: 1 } },
      opts
    ));
  if (!user) {
    return { points: 0, xp: 0, rewardedToday: REVIEW_REWARD_DAILY_CAP };
  }
  // level เป็น cache ของ xp (แบบ utils/questRewards.js) — คิดใหม่หลัง xp เปลี่ยน
  await User.updateOne({ _id: userId }, { $set: { level: progression.levelFromXp(user.xp) } });
  return { ...REVIEW_REWARD, rewardedToday: user.reviewRewardCount };
};

module.exports = { REVIEW_REWARD, REVIEW_REWARD_DAILY_CAP, rewardedToday, awardReviewer };
