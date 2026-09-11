const UserUpgrade = require('../models/UserUpgrade');
const User = require('../models/User');

// รวมนิยาม + สูตรของ upgrade ทั้งหมดไว้ไฟล์เดียว — แนวเดียวกับ progression.js (level/rank)
// และ MEDALS/ITEMS ใน utils/achievements.js / utils/inventory.js
// ทุกที่ในระบบที่ต้องคิดผลของ upgrade ต้องเรียกจากไฟล์นี้ ห้าม hardcode สูตรซ้ำที่อื่น
//
// upgradeType ห้ามเปลี่ยนหลังมีคนซื้อไปแล้ว เพราะเป็นคีย์ที่บันทึกลง DB
// (มี unique index (userId, upgradeType) กันซื้อซ้ำเป็นหลายแถวอยู่ที่ models/UserUpgrade.js)
//
// ทุก upgrade เพิ่มผล 1% ต่อระดับ ซื้อซ้ำได้สูงสุด maxLevel ครั้ง ราคาแพงขึ้นทุกระดับ
// (costForNextLevel คูณตาม "ระดับที่กำลังจะซื้อ" ไม่ใช่ระดับปัจจุบัน)
//
// ⚠️ quest_unlock จำกัด maxLevel ไว้ที่ 14 (ไม่ใช่ 50 เหมือนตัวอื่น) เพราะทั้งระบบมี solo quest
// อยู่แค่ 18 อัน เริ่มเห็น 4 อันตั้งต้น เหลืออีก 14 อันให้ปลดครบพอดี ถ้าปล่อยถึง 50 ระดับท้ายๆ
// จะเก็บแต้มไปแล้วไม่ได้อะไรเพิ่มเลย (เพิ่มเควสใหม่ทีหลังก็ปรับเลขนี้ขึ้นตามได้)
const UPGRADES = [
  {
    upgradeType: 'point_booster',
    title: 'Point Booster',
    description: 'Increase points earned from every quest by 1% per level.',
    baseCost: 20,
    maxLevel: 50,
  },
  {
    upgradeType: 'xp_booster',
    title: 'XP Booster',
    description: 'Increase XP earned from every quest by 1% per level (raises your Level).',
    baseCost: 20,
    maxLevel: 50,
  },
  {
    upgradeType: 'rank_booster',
    title: 'Rank Booster',
    // Rank คิดจาก XP สะสมในซีซั่นนี้เท่านั้น (ดู utils/profilePayload.js) แยกจาก XP รวมที่ใช้คิด Level
    // เจตนาให้แยกกัน ไม่ใช่บั๊ก — ซื้อ XP Booster ไม่ได้ทำให้ Rank ขยับเร็วขึ้นด้วย ต้องซื้อตัวนี้แยก
    description: 'Increase season XP earned from every quest by 1% per level (raises your Rank).',
    baseCost: 20,
    maxLevel: 50,
  },
  {
    upgradeType: 'party_bonus',
    title: 'Party Bonus Points',
    description: 'Increase points earned from Party quests by an extra 1% per level.',
    baseCost: 20,
    maxLevel: 50,
  },
  {
    upgradeType: 'quest_unlock',
    title: 'Quest Unlock',
    description: 'Reveal 1 more quest in Explore per level.',
    baseCost: 20,
    maxLevel: 14,
  },
];

const BASE_VISIBLE_QUESTS = 4;

const findUpgrade = (upgradeType) => UPGRADES.find((u) => u.upgradeType === upgradeType);

// ราคาของ "ระดับถัดไป" ที่กำลังจะซื้อ (currentLevel = ระดับที่มีอยู่ตอนนี้)
// เช่น baseCost 20: ซื้อระดับ 1 = 20, ระดับ 2 = 40, ... ระดับ 50 = 1000
const costForNextLevel = (upgrade, currentLevel) => upgrade.baseCost * (currentLevel + 1);

// แปลงแถว UserUpgrade ที่ query มาแล้วให้เป็นก้อนโบนัสพร้อมใช้
const bonusesFromRows = (rows) => {
  const levelOf = (type) => rows.find((r) => r.upgradeType === type)?.level || 0;
  return {
    pointPct: levelOf('point_booster'),
    xpPct: levelOf('xp_booster'),
    rankPct: levelOf('rank_booster'),
    partyPct: levelOf('party_bonus'),
    questSlots: levelOf('quest_unlock'),
  };
};

// รวมระดับ upgrade ทั้งหมดของ user เป็นตัวคูณ/โบนัสพร้อมใช้ — query ครั้งเดียวจบ
const getUserBonuses = async (userId) => {
  const rows = await UserUpgrade.find({ userId }).select('upgradeType level');
  return bonusesFromRows(rows);
};

// เหมือน getUserBonuses แต่ดึงหลาย user พร้อมกันทีเดียว (ใช้ในลูปแจกรางวัลปาร์ตี้
// กันไม่ให้ query ต่อคนต่อรอบ) คืนเป็น Map<userId string, bonuses>
const getUserBonusesMap = async (userIds) => {
  const rows = await UserUpgrade.find({ userId: { $in: userIds } }).select('userId upgradeType level');
  const byUser = new Map();

  for (const id of userIds) {
    const idStr = String(id);
    byUser.set(idStr, bonusesFromRows(rows.filter((r) => String(r.userId) === idStr)));
  }
  return byUser;
};

// คิดคะแนน/XP ที่จะได้จริงของเควสหนึ่งอัน หลังคูณโบนัสของ user คนนี้แล้ว
// ต้องเรียกครั้งเดียวแล้วใช้ค่าเดิมทุกจุด (QuestHistory, user.points/xp, response, notification)
// ไม่งั้นตัวเลขที่โชว์กับที่บันทึกจริงจะไม่ตรงกัน
const applyBonuses = (bonuses, quest) => {
  const isParty = quest.type === 'party';
  const pointMultiplier = 1 + bonuses.pointPct / 100 + (isParty ? bonuses.partyPct / 100 : 0);
  const xpMultiplier = 1 + bonuses.xpPct / 100;
  const rankMultiplier = 1 + bonuses.rankPct / 100;

  return {
    points: Math.round(quest.scorePoints * pointMultiplier),
    xp: Math.round(quest.xpReward * xpMultiplier),
    // rankXp เขียนแยกลง QuestHistory.xpEarned ต่างหากจาก xp ที่ใช้คิด Level โดยตั้งใจ
    rankXp: Math.round(quest.xpReward * rankMultiplier),
  };
};

// จำนวน solo quest ที่ user คนนี้ควรเห็น (ตั้งต้น 4 อัน + เพิ่มตาม quest_unlock)
const visibleSoloQuestCount = async (userId) => {
  const bonuses = await getUserBonuses(userId);
  return BASE_VISIBLE_QUESTS + bonuses.questSlots;
};

// รายการ upgrade ทั้งหมด + ระดับที่ user มี + ราคาระดับถัดไป (ให้แอพโชว์การ์ดร้านค้าได้เลย)
const getUpgrades = async (userId) => {
  const rows = await UserUpgrade.find({ userId }).select('upgradeType level');
  const levelMap = new Map(rows.map((r) => [r.upgradeType, r.level]));

  return UPGRADES.map((upgrade) => {
    const level = levelMap.get(upgrade.upgradeType) || 0;
    const maxed = level >= upgrade.maxLevel;

    return {
      upgradeType: upgrade.upgradeType,
      title: upgrade.title,
      description: upgrade.description,
      level,
      maxLevel: upgrade.maxLevel,
      // เต็มระดับแล้วไม่มีราคาถัดไปให้ซื้อ
      nextCost: maxed ? null : costForNextLevel(upgrade, level),
    };
  });
};

// ซื้อ upgrade 1 ระดับ — หักแต้มแบบ atomic (compare-and-swap ในเงื่อนไข query เดียวกับที่
// routes/party.js ใช้กันคะแนนซ้ำ) กันทั้งแต้มติดลบและกดซื้อซ้อนกันพร้อมกันหลาย request
const buyUpgrade = async (userId, upgradeType) => {
  const upgrade = findUpgrade(upgradeType);
  if (!upgrade) {
    return { error: { status: 404, message: 'Upgrade not found' } };
  }

  const existing = await UserUpgrade.findOne({ userId, upgradeType }).select('level');
  const currentLevel = existing?.level || 0;

  if (currentLevel >= upgrade.maxLevel) {
    return { error: { status: 400, message: 'This upgrade is already at max level' } };
  }

  const cost = costForNextLevel(upgrade, currentLevel);

  const user = await User.findOneAndUpdate(
    { _id: userId, points: { $gte: cost } },
    { $inc: { points: -cost } },
    { new: true }
  );

  if (!user) {
    return { error: { status: 400, message: 'Not enough points' } };
  }

  let saved;
  try {
    saved = await UserUpgrade.findOneAndUpdate(
      { userId, upgradeType },
      { $inc: { level: 1 } },
      { upsert: true, new: true }
    );
  } catch (err) {
    // อัพระดับไม่สำเร็จ ต้องคืนแต้มที่หักไปแล้ว ไม่งั้นผู้ใช้เสียแต้มฟรีโดยไม่ได้อะไรเลย
    await User.updateOne({ _id: userId }, { $inc: { points: cost } });
    throw err;
  }

  return {
    upgrade: {
      upgradeType: upgrade.upgradeType,
      title: upgrade.title,
      description: upgrade.description,
      level: saved.level,
      maxLevel: upgrade.maxLevel,
      nextCost: saved.level >= upgrade.maxLevel ? null : costForNextLevel(upgrade, saved.level),
    },
    points: user.points,
  };
};

module.exports = {
  UPGRADES,
  BASE_VISIBLE_QUESTS,
  getUserBonuses,
  getUserBonusesMap,
  applyBonuses,
  visibleSoloQuestCount,
  getUpgrades,
  buyUpgrade,
};
