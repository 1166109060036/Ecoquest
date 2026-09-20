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
// slot           = ของตกแต่งโปรไฟล์ (frame/nameStyle/background/effect) — "การมี slot" คือตัวบอกว่า
//                  ไอเทมนี้เป็นของตกแต่ง ซึ่งต่างจากไอเทมทั่วไป 3 อย่าง: ซื้อซ้ำไม่ได้ (ดู buyItem),
//                  ใช้ไม่ได้ (ไม่มี effect เลย useItem ปฏิเสธให้เองอยู่แล้ว) และใส่/ถอดได้ผ่าน
//                  equipCosmetics แทน โดยของที่ใส่อยู่เก็บไว้ที่ User.cosmetics ไม่ใช่ที่ InventoryItem
//
// ⚠️ ราคา/ตัวคูณตรงนี้ผ่านการทดสอบ balance รอบแรกแล้ว (ดู BALANCE_REPORT.md ที่ root — จำลอง
// Casual/Normal/Active player 7/14/30 วัน + ROI ของแต่ละไอเทม/upgrade) ปรับต่อได้ที่เดียวตรงนี้เลย
// (อ้างอิง: เควสทั่วไปได้ 10-15 P ผู้เล่นใหม่เห็น 6 เควสแรก = 70 P/วัน, Upgrade 1 สายเต็ม (booster)
// = 1,520 P — ของตกแต่งทั้งหมด 12 ชิ้นรวมกัน 4,400 P จงใจให้ถูกกว่า Upgrade 1 สาย จะได้ไม่ไปแย่งงบ
// กับสายพลัง)
const COSMETIC_SLOTS = ['frame', 'nameStyle', 'background', 'effect'];

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
    // ⚠️ ลดจาก 100 → 70 P: ผู้เล่นใหม่ (6 เควสแรก เฉลี่ย ~11.7 P/เควส) ที่ 100 P ต้องทำเควสเพิ่ม
    // 9 อันถึงจะคืนทุน แต่มีแค่ 6 อันให้ทำต่อวัน = ขาดทุนเสมอ ที่ 70 P ทำเพิ่มแค่ ~6 อันก็คืนทุนพอดี
    // (ตรงกับเกณฑ์ในเอกสาร balance เองที่บอกว่า "ได้เพิ่ม ~5 เควสขึ้นไป = ราคาสมเหตุสมผล")
    cost: 70,
    effect: 'super_energy',
  },
  // ---- ของตกแต่งโปรไฟล์ (slot) — ซื้อด้วย Point อย่างเดียว ไม่มีเงื่อนไขเลเวล/เหรียญ ----
  {
    itemType: 'name_mint',
    slot: 'nameStyle',
    title: 'Mint',
    description: 'A cool mint color for your display name.',
    cost: 150,
  },
  {
    itemType: 'name_sunset',
    slot: 'nameStyle',
    title: 'Sunset',
    description: 'A warm orange-to-pink gradient for your display name.',
    cost: 150,
  },
  {
    itemType: 'name_aurora',
    slot: 'nameStyle',
    title: 'Aurora',
    description: 'A glowing green-to-purple gradient for your display name.',
    cost: 300,
  },
  {
    itemType: 'frame_leaf',
    slot: 'frame',
    title: 'Emerald Leaf',
    description: 'A green gradient ring around your avatar.',
    cost: 250,
  },
  {
    itemType: 'frame_ocean',
    slot: 'frame',
    title: 'Ocean Wave',
    description: 'A blue gradient ring around your avatar.',
    cost: 250,
  },
  {
    itemType: 'frame_gold',
    slot: 'frame',
    title: 'Golden Sun',
    description: 'A glowing golden ring around your avatar.',
    cost: 500,
  },
  {
    itemType: 'fx_leaves',
    slot: 'effect',
    title: 'Falling Leaves',
    description: 'Leaves gently falling across your profile.',
    cost: 400,
  },
  {
    itemType: 'fx_snow',
    slot: 'effect',
    title: 'Snowfall',
    description: 'Snow gently falling across your profile.',
    cost: 400,
  },
  {
    itemType: 'fx_rain',
    slot: 'effect',
    title: 'Rainfall',
    description: 'Rain falling across your profile.',
    cost: 400,
  },
  {
    itemType: 'fx_ember',
    slot: 'effect',
    title: 'Embers',
    description: 'Glowing embers drifting up your profile.',
    cost: 400,
  },
  {
    itemType: 'bg_forest',
    slot: 'background',
    title: 'Deep Forest',
    description: 'A deep forest green backdrop for your profile.',
    cost: 600,
  },
  {
    itemType: 'bg_night',
    slot: 'background',
    title: 'Starry Night',
    description: 'A starry night sky backdrop for your profile.',
    cost: 600,
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
    // มีค่า = ของตกแต่งโปรไฟล์ (frame/nameStyle/background/effect) — ไม่มีค่า = ไอเทมทั่วไป
    slot: item.slot ?? null,
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

  try {
    if (item.slot) {
      // ของตกแต่งซื้อได้แค่ครั้งเดียว (มีติดตัวแล้วไม่มีประโยชน์จะมีอีกชิ้น ไม่เหมือนไอเทม Energy
      // ที่ซื้อสะสมได้) — ใช้ upsert ล้วนๆ ไม่มี $inc แล้วเช็คว่า "เพิ่งสร้างแถวใหม่จริงไหม" จากผลลัพธ์
      // เท่านั้น (ห้ามเช็คด้วย exists() ก่อนหน้า เพราะกดซื้อรัวพร้อมกัน 2 request จะลอดผ่านได้ทั้งคู่)
      const result = await InventoryItem.updateOne(
        { userId, itemType },
        { $setOnInsert: { userId, itemType, quantity: 1 } },
        { upsert: true }
      );
      if (!result.upsertedCount) {
        // มีอยู่แล้ว — คืนแต้มที่หักไปข้างบน ไม่งั้นกดปุ่มซ้อน/กดซ้ำจะเสียแต้มฟรีโดยไม่ได้อะไรเพิ่ม
        await User.updateOne({ _id: userId }, { $inc: { points: item.cost } });
        return { error: { status: 400, message: 'You already own this item' } };
      }
      return { itemType, quantity: 1, points: user.points };
    }

    const saved = await InventoryItem.findOneAndUpdate(
      { userId, itemType },
      { $inc: { quantity: 1 }, $setOnInsert: { userId, itemType } },
      { upsert: true, new: true }
    );
    return { itemType, quantity: saved.quantity, points: user.points };
  } catch (err) {
    // เพิ่มไอเทมไม่สำเร็จ ต้องคืนแต้มที่หักไปแล้ว ไม่งั้นผู้ใช้เสียแต้มฟรีโดยไม่ได้อะไรเลย
    await User.updateOne({ _id: userId }, { $inc: { points: item.cost } });
    throw err;
  }
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

// ใส่/ถอดของตกแต่งโปรไฟล์ — patch เป็น partial ของ 4 ช่อง {frame, nameStyle, background, effect}
// ค่า null = ถอดช่องนั้น, ช่องที่ไม่ส่งมาใน patch = ไม่แตะ (สลับหลายช่องพร้อมกันได้ในคำขอเดียว
// ไม่ต้องมี endpoint ถอดแยกต่างหาก) ตอบกลับ cosmetics ทั้ง 4 ช่องเสมอให้แอพแทนที่ state ทั้งก้อน
const equipCosmetics = async (userId, patch) => {
  const keys = Object.keys(patch);

  for (const key of keys) {
    if (!COSMETIC_SLOTS.includes(key)) {
      return { error: { status: 400, message: `Invalid cosmetic slot: ${key}` } };
    }
  }

  // เช็คว่าแต่ละค่าที่จะใส่มีจริงใน catalogue และ slot ตรงกับช่องที่จะใส่ก่อน ค่อยไปเช็คความเป็นเจ้าของ
  const itemTypesToOwn = [];
  for (const key of keys) {
    const value = patch[key];
    if (value === null) continue;
    const item = findItem(value);
    if (!item) {
      return { error: { status: 404, message: 'Cosmetic not found' } };
    }
    if (item.slot !== key) {
      return { error: { status: 400, message: 'Item does not fit this slot' } };
    }
    itemTypesToOwn.push(value);
  }

  if (itemTypesToOwn.length > 0) {
    // query เดียวเช็คทุกชิ้นพร้อมกัน ไม่ query ทีละชิ้น
    const owned = await InventoryItem.find({
      userId,
      itemType: { $in: itemTypesToOwn },
      quantity: { $gte: 1 },
    }).select('itemType');
    const ownedSet = new Set(owned.map((row) => row.itemType));
    const missing = itemTypesToOwn.find((itemType) => !ownedSet.has(itemType));
    if (missing) {
      return { error: { status: 403, message: 'You do not own this cosmetic' } };
    }
  }

  const setFields = {};
  for (const key of keys) {
    setFields[`cosmetics.${key}`] = patch[key];
  }

  const user = await User.findByIdAndUpdate(userId, { $set: setFields }, { new: true }).select(
    'cosmetics'
  );

  return { cosmetics: user.cosmetics };
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

module.exports = { ITEMS, getInventory, buyItem, useItem, equipCosmetics, withEnergyBoosts };
