const Notification = require('../models/Notification');
const FridgeItem = require('../models/FridgeItem');
const { startOfToday } = require('./questDay');

// สร้างแจ้งเตือน 1 ใบแบบ idempotent — ถ้ามี (userId, dedupeKey) นี้อยู่แล้วจะไม่ทำอะไรเลย
// ต้องใช้ $setOnInsert เท่านั้น (ไม่ใช่ $set) ไม่งั้นแถวเดิมที่ผู้ใช้อ่านไปแล้ว (readAt ไม่ null)
// จะโดนเขียนทับกลับเป็นข้อมูลใหม่ตอน upsert ซ้ำ ทำให้ readAt หายและจุดแดงขึ้นใหม่ทั้งที่เคยอ่านแล้ว
const createNotification = async ({ userId, type, title, message, dedupeKey }) => {
  try {
    await Notification.updateOne(
      { userId, dedupeKey },
      { $setOnInsert: { userId, type, title, message, dedupeKey } },
      { upsert: true }
    );
  } catch (err) {
    // ชนกับ unique index = มีอีก request สร้างพร้อมกันพอดี ไม่ถือว่าพัง (เหมือน syncAchievements)
    if (err.code !== 11000) throw err;
  }
};

// ทำเควสสำเร็จ (ทั้ง solo และ party) — dedupeKey อิง questHistoryId เพราะเควสรายวัน/รายวันของปาร์ตี้
// ทำซ้ำได้คนละวัน แต่ละครั้งที่ทำสำเร็จควรได้แจ้งเตือนเป็นใบใหม่
//
// ⚠️ pointsEarned ต้องเป็นแต้มที่ "คูณ upgrade แล้ว" (ผลจาก utils/upgrades.js#applyBonuses)
// ไม่ใช่ quest.scorePoints ตรงๆ ไม่งั้นข้อความจะโชว์แต้มฐานที่ไม่ตรงกับที่ผู้เล่นได้จริง
const notifyQuestCompleted = async (userId, quest, questHistoryId, pointsEarned) => {
  await createNotification({
    userId,
    type: 'quest_complete',
    title: 'Quest Completed',
    message: `${quest.title} · +${pointsEarned} points`,
    dedupeKey: `quest:${questHistoryId}`,
  });
};

// ปลดล็อกเหรียญ Achievement — medalType ปลดล็อกได้ครั้งเดียวต่อคนอยู่แล้ว (unique index ที่ Achievement.js)
// เลยใช้ medalType ตรงๆ เป็น dedupeKey ได้เลย ไม่ต้องพ่วง timestamp
const notifyAchievementUnlocked = async (userId, medal) => {
  await createNotification({
    userId,
    type: 'achievement',
    title: 'Achievement Unlocked',
    message: `${medal.title} — ${medal.description}`,
    dedupeKey: `medal:${medal.medalType}`,
  });
};

// ของในตู้เย็นที่เหลือไม่เกิน 24 ชม. หรือหมดอายุไปแล้ว — สร้างตอนอ่าน (lazy) เพราะ backend ไม่มี
// scheduler/cron และ Render free tier หลับเมื่อไม่มีคนใช้ เลยพึ่ง cron จริงไม่ได้
// bucket 'soon'/'expired' แยกกัน เลยได้แจ้งเตือนคนละใบตอนของเลยกำหนดจากที่เคยเตือนไว้ก่อนหน้า
const ensureExpiryNotifications = async (userId) => {
  const now = new Date();
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const items = await FridgeItem.find({
    userId,
    expirationDate: { $lte: in24h },
  });

  await Promise.all(
    items.map((item) => {
      const expired = item.expirationDate <= now;
      const bucket = expired ? 'expired' : 'soon';
      const dateLabel = `${item.expirationDate.getDate()}/${item.expirationDate.getMonth() + 1}/${item.expirationDate.getFullYear()}`;

      return createNotification({
        userId,
        type: 'fridge_expiring',
        title: expired ? 'Item Expired' : 'Almost Expired',
        message: expired
          ? `${item.itemName} expired on ${dateLabel}.`
          : `${item.itemName} expires on ${dateLabel}, only 24 hours remain.`,
        dedupeKey: `expiry:${item._id}:${bucket}`,
      });
    })
  );
};

// แจ้งเตือนทั้งหมดของ user คนนี้ (ล่าสุดขึ้นก่อน) — เรียก ensureExpiryNotifications ก่อนเสมอ
// เพื่อให้ของที่ใกล้หมดอายุตอนนี้โผล่ในลิสต์แม้จะยังไม่เคยเปิดหน้านี้มาก่อน
const getNotifications = async (userId) => {
  await ensureExpiryNotifications(userId);

  return Notification.find({ userId })
    .sort({ createdAt: -1 })
    .limit(50);
};

// เข้าหน้า Notification แล้วถือว่าอ่านหมด
const markAllRead = async (userId) => {
  await Notification.updateMany({ userId, readAt: null }, { $set: { readAt: new Date() } });
};

// ลบของออกจากตู้เย็นแล้ว ลบแจ้งเตือนของชิ้นนั้นทิ้งด้วย ไม่งั้นค้างเตือนถึงของที่กินไปแล้ว
const deleteExpiryNotifications = async (userId, fridgeItemId) => {
  await Notification.deleteMany({
    userId,
    dedupeKey: { $in: [`expiry:${fridgeItemId}:soon`, `expiry:${fridgeItemId}:expired`] },
  });
};

module.exports = {
  createNotification,
  notifyQuestCompleted,
  notifyAchievementUnlocked,
  ensureExpiryNotifications,
  getNotifications,
  markAllRead,
  deleteExpiryNotifications,
};
