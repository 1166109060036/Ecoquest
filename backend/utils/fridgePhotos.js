// ลบรูปของในตู้เย็นที่หมดอายุแล้ว (ผู้ใช้สั่ง 1 ต.ค. 2026 — กัน Atlas ฟรี 512MB เต็มจากรูป)
// ลบแค่รูป ตัวรายการยังอยู่ — ผู้ใช้เป็นคนตัดสินใจลบของเอง (กดค้าง / ปุ่ม Remove ในหน้า Fridge)
// "หมดอายุ" = expirationDate <= ตอนนี้ ตรงกับ FridgeItemModel.isExpiredAt ฝั่งแอพ และแจ้งเตือน 'expired'
// photoRemovedAt = แอพรู้ว่าของชิ้นนี้เคยมีรูป (โชว์ "photo removed" แทนเงียบหาย)
const FridgeItem = require('../models/FridgeItem');

const purgeExpiredFridgePhotos = (extraFilter = {}) =>
  FridgeItem.updateMany(
    { ...extraFilter, photoContentType: { $ne: null }, expirationDate: { $lte: new Date() } },
    { $set: { photoData: null, photoContentType: null, photoRemovedAt: new Date() } }
  );

module.exports = { purgeExpiredFridgePhotos };
