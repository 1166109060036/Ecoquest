const Season = require('../models/Season');

// รวม logic ของ season ไว้ไฟล์เดียว — แนวเดียวกับ progression.js/upgrades.js
// ทุกที่ในระบบที่ต้องใช้ season ปัจจุบันต้องเรียกผ่าน ensureActiveSeason() เท่านั้น
// ห้าม query Season.findOne({isActive:true}) ตรงๆ ที่อื่น ไม่งั้นจะพลาดการเช็คว่าหมดอายุหรือยัง
//
// backend ไม่มี scheduler/cron เลย (Render free tier หลับเมื่อไม่มีคนใช้ พึ่ง cron จริงไม่ได้)
// เลยต้องปิดซีซั่นเก่า/เปิดซีซั่นใหม่แบบ "เช็คตอนมีคนเรียก API" (lazy) เหมือนที่
// utils/notifications.js#ensureExpiryNotifications ทำกับของใกล้หมดอายุ ไม่ใช่พึ่งแค่ตอน boot
const SEASON_DURATION_DAYS = 90;

const addDays = (date, days) => new Date(date.getTime() + days * 24 * 60 * 60 * 1000);

// จำนวนวันที่เหลือของ season (ปัดขึ้น เพื่อไม่ให้โชว์ "0 days left" ทั้งที่จริงยังเหลือไม่กี่ชั่วโมง)
const daysRemaining = (season) => {
  const ms = season.endDate.getTime() - Date.now();
  return Math.max(0, Math.ceil(ms / (24 * 60 * 60 * 1000)));
};

// เปิด season ถัดไปต่อจาก season ที่ปิดไปแล้ว (หรือ season แรกถ้ายังไม่เคยมีเลย)
// startDate ของอันใหม่ = endDate ของอันเก่า (ไม่ใช่ "ตอนนี้") กันวันที่คลาดเคลื่อนถ้าเช็คช้ากว่ากำหนด
const openNextSeason = async (previousSeason) => {
  const seasonNumber = previousSeason ? previousSeason.seasonNumber + 1 : 1;
  const startDate = previousSeason ? previousSeason.endDate : new Date();
  const endDate = addDays(startDate, SEASON_DURATION_DAYS);

  // upsert กัน race — ถ้ามีอีก request มาเปิดเลขเดียวกันพอดี unique index (seasonNumber) จะกันซ้ำให้
  return Season.findOneAndUpdate(
    { seasonNumber },
    { seasonNumber, startDate, endDate, isActive: true },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
};

// คืน season ที่ active อยู่ตอนนี้เสมอ — สร้าง/หมุนให้อัตโนมัติถ้าจำเป็น เรียกซ้ำได้ปลอดภัย (idempotent)
const ensureActiveSeason = async () => {
  const current = await Season.findOne({ isActive: true });

  if (!current) {
    // ไม่มี season ที่ active เลย — สองเคสนี้ต่างกัน ต้องแยกให้ออก:
    //   1) ยังไม่เคยมี season มาก่อนจริงๆ -> เปิด season 1
    //   2) อีก request กำลังปิดซีซั่นเก่า/เปิดซีซั่นใหม่อยู่พอดี (ช่วงสั้นๆ ระหว่างสองขั้นตอนของมัน)
    //      ถ้าเข้าใจผิดว่าเป็นเคส 1 จะไปเปิด season 1 ทับซีซั่นที่มีอยู่แล้วโดยไม่ตั้งใจ
    // เช็คจาก season ล่าสุดที่เคยมี (ไม่สนใจ isActive) เพื่อแยกสองเคสนี้ออกจากกัน
    const latest = await Season.findOne().sort({ seasonNumber: -1 });
    if (!latest) {
      return openNextSeason(null);
    }
    if (!latest.isActive) {
      // เจอ gap สั้นๆ ระหว่างอีก request ปิด/เปิดซีซั่นอยู่พอดี — เช็คใหม่จะเจอผลลัพธ์ที่เพิ่งเปิดเสร็จ
      return ensureActiveSeason();
    }
    return latest;
  }

  // ยังไม่หมดอายุ -> ใช้ตัวเดิมได้เลย
  if (current.endDate > new Date()) {
    return current;
  }

  // หมดอายุแล้ว -> ปิดตัวเดิมแบบ compare-and-swap (กันสอง request ปิดซ้อนกันพอดีตอนหมดอายุ)
  // แบบเดียวกับ latch ที่ routes/party.js ใช้กันคะแนนซ้ำตอนหัวหน้ากดจบอีเวนต์
  const closed = await Season.findOneAndUpdate(
    { _id: current._id, isActive: true },
    { isActive: false },
    { new: false }
  );

  if (!closed) {
    // อีก request ปิด+เปิดซีซั่นใหม่ไปพร้อมกันพอดี — เช็คใหม่ตั้งแต่ต้นจะเจอซีซั่นใหม่ที่เพิ่งเปิด
    return ensureActiveSeason();
  }

  // เปิดซีซั่นถัดไป — ถ้าซีซั่นเก่าหมดอายุไปหลายรอบแล้ว (เช่นไม่มีใครเข้าแอพนาน) เรียกตัวเองซ้ำ
  // ให้ไล่เปิด-ปิดทีละซีซั่นจนกว่าจะถึงซีซั่นที่ยัง cover เวลาปัจจุบันอยู่ ไม่กระโดดข้ามเลข
  const next = await openNextSeason(closed);
  if (next.endDate <= new Date()) {
    return ensureActiveSeason();
  }
  return next;
};

module.exports = { SEASON_DURATION_DAYS, ensureActiveSeason, daysRemaining };
