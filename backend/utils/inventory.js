const InventoryItem = require('../models/InventoryItem');

// รวมนิยามไอเทมทั้งหมดไว้ไฟล์เดียว — แนวเดียวกับ MEDALS ใน utils/achievements.js
// itemType ห้ามเปลี่ยนหลังมีคนได้ไอเทมนั้นไปแล้ว เพราะเป็นคีย์ที่บันทึกลง DB
// (มี unique index (userId, itemType) กันซ้ำอยู่ที่ models/InventoryItem.js)
//
// starter: true = ไอเทมที่ผู้เล่นทุกคนต้องมีติดตัวตั้งแต่แรก (ไม่ใช่ของที่ได้จาก quest/reward)
const ITEMS = [
  {
    itemType: 'camera',
    title: 'Camera',
    description: 'Take photos to capture good moments.',
    starter: true,
  },
  {
    itemType: 'fridge',
    title: 'Fridge',
    description: 'View saved food items and their expiration dates.',
    starter: true,
  },
];

// แจกไอเทมตั้งต้นให้ user คนนี้ถ้ายังไม่มี — เขียนเป็น upsert เลยรันซ้ำได้ ไม่สร้างแถวซ้ำ
// (เรียกทุกครั้งที่ GET /api/inventory แทนที่จะแจกตอนสมัคร เพื่อให้บัญชีเก่าที่มีอยู่แล้วก่อนฟีเจอร์นี้
// ได้ของไปด้วยโดยไม่ต้อง backfill DB เอง)
const ensureStarterItems = async (userId) => {
  const starterItems = ITEMS.filter((item) => item.starter);

  await Promise.all(
    starterItems.map((item) =>
      InventoryItem.findOneAndUpdate(
        { userId, itemType: item.itemType },
        { userId, itemType: item.itemType },
        { upsert: true, setDefaultsOnInsert: true }
      )
    )
  );
};

// ไอเทมทั้งหมดที่ user คนนี้มี — join กับ catalogue เอาแค่ title/description มาให้แอพใช้เลย
const getInventory = async (userId) => {
  await ensureStarterItems(userId);

  const rows = await InventoryItem.find({ userId }).select('itemType quantity');
  const catalogueMap = new Map(ITEMS.map((item) => [item.itemType, item]));

  return rows
    // ข้าม itemType ที่ไม่มีในนิยามแล้ว (เช่นเคยมีไอเทมนี้แต่ถูกเอาออกจาก catalogue ไปแล้ว)
    .filter((row) => catalogueMap.has(row.itemType))
    .map((row) => {
      const item = catalogueMap.get(row.itemType);
      return {
        itemType: row.itemType,
        title: item.title,
        description: item.description,
        quantity: row.quantity,
      };
    });
};

module.exports = { ITEMS, getInventory };
