// รวม "สูตร" ของระบบ progression ทั้งหมดไว้ไฟล์เดียว — อยากปรับความยากของเกมแก้ที่นี่ที่เดียวพอ
// (level curve, rank tier, energy regen) ทุกที่ในระบบต้องเรียกใช้จากไฟล์นี้ ห้าม hardcode ซ้ำที่อื่น

// ---------------------------------------------------------------------------
// Level — คำนวณจาก XP สะสม (XP ไม่ reset ตลอดกาล ตามดีไซน์)
// ---------------------------------------------------------------------------
// XP ที่ต้องใช้เลื่อนจาก level L ไป L+1 = XP_PER_LEVEL_STEP * L
// เช่น 1->2 ใช้ 100, 2->3 ใช้ 200, 3->4 ใช้ 300 (ยิ่ง level สูงยิ่งใช้เยอะขึ้นแบบเชิงเส้น)
const XP_PER_LEVEL_STEP = 100;
const MAX_LEVEL = 100;

// XP สะสมทั้งหมดที่ต้องมี เพื่อ "ถึง" level นี้พอดี
const totalXpForLevel = (level) => (XP_PER_LEVEL_STEP * (level - 1) * level) / 2;

const levelFromXp = (xp) => {
  let level = 1;
  while (level < MAX_LEVEL && totalXpForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
};

// คืนทั้ง level และความคืบหน้าภายใน level ปัจจุบัน (เอาไปทำ progress bar ได้เลย)
const levelProgress = (xp = 0) => {
  const level = levelFromXp(xp);
  const currentFloor = totalXpForLevel(level);
  const nextFloor = totalXpForLevel(level + 1);

  return {
    level,
    xp,
    xpIntoLevel: xp - currentFloor,
    xpForNextLevel: nextFloor - currentFloor,
  };
};

// ---------------------------------------------------------------------------
// Rank — อิงจาก XP ที่ได้ "ภายใน season ปัจจุบัน" เท่านั้น (จึง reset เองทุก season)
// ---------------------------------------------------------------------------
const RANK_TIERS = [
  { name: 'Bronze', minXp: 0 },
  { name: 'Silver', minXp: 500 },
  { name: 'Gold', minXp: 1500 },
  { name: 'Platinum', minXp: 3000 },
  { name: 'Diamond', minXp: 5000 },
];

const rankProgress = (seasonXp = 0) => {
  let index = 0;
  for (let i = 0; i < RANK_TIERS.length; i++) {
    if (seasonXp >= RANK_TIERS[i].minXp) index = i;
  }

  const current = RANK_TIERS[index];
  const next = RANK_TIERS[index + 1];

  return {
    rankTier: current.name,
    seasonXp,
    rankXpIntoTier: seasonXp - current.minXp,
    // null = อยู่ tier สูงสุดแล้ว ไม่มีขั้นถัดไปให้ไต่
    rankXpForNextTier: next ? next.minXp - current.minXp : null,
  };
};

// ---------------------------------------------------------------------------
// Energy — เต็ม 5 ฟื้น +1 ทุก 5 นาที
// ---------------------------------------------------------------------------
const MAX_ENERGY = 5;
const ENERGY_REGEN_MS = 5 * 60 * 1000;

// คำนวณ energy ณ ปัจจุบันแบบ lazy: ไม่เขียน DB ตอนอ่าน คิดจาก lastEnergyUpdate เอา
// (จะ persist ลง DB จริงเฉพาะตอน "ใช้" energy เช่นตอนทำ quest สำเร็จเท่านั้น)
const currentEnergy = (energy = MAX_ENERGY, lastEnergyUpdate = new Date()) => {
  if (energy >= MAX_ENERGY) return MAX_ENERGY;

  const elapsedMs = Date.now() - new Date(lastEnergyUpdate).getTime();
  const regened = Math.max(0, Math.floor(elapsedMs / ENERGY_REGEN_MS));

  return Math.min(MAX_ENERGY, energy + regened);
};

module.exports = {
  MAX_ENERGY,
  ENERGY_REGEN_MS,
  totalXpForLevel,
  levelFromXp,
  levelProgress,
  rankProgress,
  currentEnergy,
};
