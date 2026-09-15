const InventoryItem = require('../models/InventoryItem');
const User = require('../models/User');
const QuestHistory = require('../models/QuestHistory');
const { startOfToday } = require('./questDay');

// บัฟจากไอเทม Energy อยู่ได้นาน 30 นาทีนับจากตอนใช้ (ดู useItem ด้านล่าง)
const BOOST_DURATION_MS = 30 * 60 * 1000;

// รวมนิยามไอเทมทั้งหมดไว้ไฟล์เดียว — แนวเดียวกับ MEDALS ใน utils/achievements.js /
// UPGRADES ใน utils/upgrades.js
// itemType ห้ามเปลี่ยนหลังมีคนได้ไอเทมนั้นไปแล้ว เพราะเป็นคีย์ที่บันทึกลง DB
// (มี unique index (userId, itemType) กันซ้ำอยู่ที่ models/InventoryItem.js)
//
// starter: true  = ไอเทมที่ผู้เล่นทุกคนต้องมีติดตัวตั้งแต่แรก (ไม่ใช่ของที่ซื้อ/ใช้ได้)
// cost           = ราคาซื้อ 1 ชิ้นด้วย Points ผ่าน POST /:itemType/buy — ไม่มี cost = ซื้อไม่ได้
// effect         = สิ่งที่เกิดขึ้นตอนใช้ผ่าน POST /:itemType/use — ไม่มี effect = ใช้ไม่ได้ (เช่น starter item)
//
// ⚠️ ราคา/ตัวคูณตรงนี้เป็นค่าเริ่มต้นที่ยังไม่ผ่านการเทสสมดุลเกมจริง ปรับได้ที่เดียวตรงนี้เลย
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
  {
    itemType: 'eco_badge',
    title: 'Eco Badge',
    description: 'Collect the Achievement medals you have unlocked.',
    starter: true,
  },
  {
    itemType: 'red_energy',
    title: 'Red Energy',
    description: 'Use to earn 2x Points from every quest for 30 minutes.',
    cost: 40,
    effect: 'red_energy',
  },
  {
    itemType: 'blue_energy',
    title: 'Blue Energy',
    description: 'Use to earn 2x XP from every quest for 30 minutes.',
    cost: 40,
    effect: 'blue_energy',
  },
  {
    itemType: 'green_energy',
    title: 'Green Energy',
    description: 'Use to earn 2x Points from Party quests for 30 minutes.',
    cost: 40,
    effect: 'green_energy',
  },
  {
    itemType: 'super_energy',
    title: 'Super Energy',
    description: "Use to reset all of today's completed quests so you can complete them again.",
    cost: 100,
    effect: 'super_energy',
  },
];

const findItem = (itemType) => ITEMS.find((i) => i.itemType === itemType);

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

// ไอเทมทั้งหมดใน catalogue — ไอเทมที่ซื้อได้ (cost != null) ส่งกลับมาเสมอแม้จะยังไม่เคยซื้อ (quantity: 0)
// เพื่อให้การ์ดร้านค้าในหน้า Profile โชว์ราคา/คำอธิบายได้โดยไม่ต้องมี endpoint แยก — ฝั่งแอพกรองเองว่า
// จะโชว์ตรงไหน: หน้า Inventory โชว์เฉพาะที่ quantity > 0 (ของที่มีจริง), การ์ดร้านค้าโชว์ทุกอันที่มี cost
const getInventory = async (userId) => {
  await ensureStarterItems(userId);

  const rows = await InventoryItem.find({ userId }).select('itemType quantity');
  const ownedMap = new Map(rows.map((row) => [row.itemType, row.quantity]));

  return ITEMS.map((item) => ({
    itemType: item.itemType,
    title: item.title,
    description: item.description,
    quantity: ownedMap.get(item.itemType) ?? 0,
    cost: item.cost ?? null,
  }));
};

// ซื้อไอเทม 1 ชิ้นด้วย Points — atomic compare-and-swap แบบเดียวกับ buyUpgrade (utils/upgrades.js)
// หักแต้มในเงื่อนไข query เดียวกันเลย กันทั้งแต้มติดลบและกดซื้อซ้อนกันพร้อมกันหลาย request
const buyItem = async (userId, itemType) => {
  const item = findItem(itemType);
  if (!item || !item.cost) {
    return { error: { status: 404, message: 'Item not found or not for sale' } };
  }

  const user = await User.findOneAndUpdate(
    { _id: userId, points: { $gte: item.cost } },
    { $inc: { points: -item.cost } },
    { new: true }
  ).select('-avatarData');

  if (!user) {
    return { error: { status: 400, message: 'Not enough points' } };
  }

  let saved;
  try {
    saved = await InventoryItem.findOneAndUpdate(
      { userId, itemType },
      { $inc: { quantity: 1 }, $setOnInsert: { userId, itemType } },
      { upsert: true, new: true }
    );
  } catch (err) {
    // เพิ่มไอเทมไม่สำเร็จ ต้องคืนแต้มที่หักไปแล้ว ไม่งั้นผู้ใช้เสียแต้มฟรีโดยไม่ได้อะไรเลย
    await User.updateOne({ _id: userId }, { $inc: { points: item.cost } });
    throw err;
  }

  return { itemType, quantity: saved.quantity, points: user.points };
};

// ใช้ไอเทม 1 ชิ้น — หักจำนวนแบบ atomic ก่อนเสมอ (เงื่อนไข quantity >= 1 อยู่ใน query เอง)
// แล้วค่อยใส่ผล กันกดรัวๆ ได้ผลไอเทมฟรีโดยไม่ได้เสียของจริง
const useItem = async (userId, itemType) => {
  const item = findItem(itemType);
  if (!item || !item.effect) {
    return { error: { status: 404, message: 'Item not found or not usable' } };
  }

  const owned = await InventoryItem.findOneAndUpdate(
    { userId, itemType, quantity: { $gte: 1 } },
    { $inc: { quantity: -1 } },
    { new: true }
  );
  if (!owned) {
    return { error: { status: 400, message: "You don't have this item" } };
  }

  const expiresAt = new Date(Date.now() + BOOST_DURATION_MS);

  switch (item.effect) {
    case 'red_energy':
      await User.updateOne({ _id: userId }, { $set: { redEnergyExpiresAt: expiresAt } });
      return { effect: item.effect, quantity: owned.quantity, expiresAt };
    case 'blue_energy':
      await User.updateOne({ _id: userId }, { $set: { blueEnergyExpiresAt: expiresAt } });
      return { effect: item.effect, quantity: owned.quantity, expiresAt };
    case 'green_energy':
      await User.updateOne({ _id: userId }, { $set: { greenEnergyExpiresAt: expiresAt } });
      return { effect: item.effect, quantity: owned.quantity, expiresAt };
    case 'super_energy': {
      // ลบประวัติทำเควส "วันนี้" ทั้งหมดทิ้ง (ทั้ง solo และ party) — completedToday/gate รายวันจะกลับมา
      // ทำได้อีกรอบทันที แต้ม/XP ที่ได้ไปแล้วก่อนหน้าไม่ถูกหักคืน (ดูเหตุผลที่ utils/questDay.js)
      const result = await QuestHistory.deleteMany({
        userId,
        completedAt: { $gte: startOfToday() },
      });
      return { effect: item.effect, quantity: owned.quantity, questsReset: result.deletedCount };
    }
    default:
      return { error: { status: 500, message: 'Unknown item effect' } };
  }
};

// เติมเปอร์เซ็นต์โบนัสจากไอเทม Energy ที่ยังไม่หมดอายุเข้าไปใน bonuses (จาก getUserBonuses/getUserBonusesMap
// ใน utils/upgrades.js) ก่อนส่งเข้า applyBonuses ตามปกติ — ไม่ต้องแก้ applyBonuses เลยเพราะมันรับแค่
// ตัวเลขเปอร์เซ็นต์อยู่แล้ว บวก 100 = คูณ 2 เท่า (ระยะเวลา 30 นาที ต้องเช็คแค่ expiresAt > ตอนนี้)
// รับ `user` ที่โหลดมาแล้ว (ต้องมี redEnergyExpiresAt/blueEnergyExpiresAt/greenEnergyExpiresAt) ไม่ query ซ้ำ
const withEnergyBoosts = (bonuses, user) => {
  const now = Date.now();
  const isActive = (expiresAt) => Boolean(expiresAt) && expiresAt.getTime() > now;

  return {
    ...bonuses,
    pointPct: bonuses.pointPct + (isActive(user.redEnergyExpiresAt) ? 100 : 0),
    xpPct: bonuses.xpPct + (isActive(user.blueEnergyExpiresAt) ? 100 : 0),
    partyPct: bonuses.partyPct + (isActive(user.greenEnergyExpiresAt) ? 100 : 0),
  };
};

module.exports = { ITEMS, getInventory, buyItem, useItem, withEnergyBoosts };
