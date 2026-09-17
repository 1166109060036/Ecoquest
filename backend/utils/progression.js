// รวม "สูตร" ของระบบ progression ทั้งหมดไว้ไฟล์เดียว — อยากปรับความยากของเกมแก้ที่นี่ที่เดียวพอ
// (level curve) ทุกที่ในระบบต้องเรียกใช้จากไฟล์นี้ ห้าม hardcode ซ้ำที่อื่น

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

// หมายเหตุ: เคยมีระบบ Energy (เต็ม 5 ฟื้น +1 ทุก 5 นาที) อยู่ในไฟล์นี้
// แต่ถูกตัดออกจากดีไซน์แล้ว — ทำ quest ได้โดยไม่เสียพลังงาน ไม่ต้องเอากลับมา
//
// หมายเหตุ: เคยมีระบบ Rank (Bronze/Silver/Gold/Platinum/Diamond อิง XP ในรอบ season) อยู่ในไฟล์นี้
// ด้วย แต่ถูกตัดออกจากดีไซน์แล้ว แทนที่ด้วยระบบ Daily Streak (ดู utils/streak.js) ไม่ต้องเอากลับมา

module.exports = {
  totalXpForLevel,
  levelFromXp,
  levelProgress,
};
