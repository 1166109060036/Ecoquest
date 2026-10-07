// เลือกเควสที่จะโชว์ในหน้า Explore ของ user แต่ละคนในแต่ละวัน
//
// - เควส alwaysVisible (ตอนนี้คือ Check Your Food & Expiration Dates) อยู่บนสุดทุกวันเสมอ
// - เควส solo ที่เหลือ "สุ่มใหม่ทุกวัน" แล้วตัดตามจำนวนที่ user เห็นได้ (BASE_VISIBLE_QUESTS + Quest Unlock)
// - กลุ่มสุ่ม (randomPool เช่น food_saver) เหลือกลุ่มละ 1 อันก่อน แล้วค่อยเข้าไปสุ่มรวมกับเควสอื่น
// - party quest โชว์ครบทุกอันเสมอ (หน้าสร้างห้องเลือกเควสจากลิสต์นี้ ห้ามโดนตัด)
//
// ทำไมสุ่มแบบ "คงที่ทั้งวัน" (hash ของ userId + วันที่) ไม่ใช่ Math.random: ถ้าสุ่มใหม่ทุกครั้งที่เรียก API
// ผู้ใช้จะดึงรีเฟรชรัวๆ จนได้เควสแต้มสูงๆ และลิสต์จะเปลี่ยนต่อหน้าต่อตา — แบบนี้คนละคนได้คนละชุด คนเดิมได้
// ชุดเดิมทั้งวัน ข้ามเที่ยงคืน (เวลาญี่ปุ่น) แล้วได้ชุดใหม่ และตัดด้วย slice หลังสุ่มลำดับแล้ว ทำให้ซื้อ Quest
// Unlock ระหว่างวันได้เควสเพิ่มต่อท้ายเฉยๆ อันเดิมไม่หาย
const crypto = require('crypto');
const { todayKey } = require('./questDay');

const dailyHash = (userId, key, dayKey) =>
  crypto.createHash('sha256').update(`${userId}-${dayKey}-${key}`).digest().readUInt32BE(0);

// allQuests: เควสที่เปิดใช้งานทั้งหมด เรียงตาม sortOrder มาแล้ว (ใช้เป็นลำดับของเควส pinned/party)
const selectVisibleQuests = (allQuests, userId, soloLimit, dayKey = todayKey()) => {
  const candidates = [];
  const pools = new Map();
  for (const q of allQuests) {
    if (!q.randomPool) {
      candidates.push(q);
      continue;
    }
    if (!pools.has(q.randomPool)) pools.set(q.randomPool, []);
    pools.get(q.randomPool).push(q);
  }
  // สุ่มถ่วงน้ำหนักด้วย poolWeight (ไม่มี = 1) — Food Saver 1/3/7 = 1/2/2 → เห็นเควสหลายวัน 80% ของวัน
  // ยังคงที่ทั้งวันเหมือนเดิม (hash ของ user + วัน) / ลำดับในกลุ่มตาม allQuests (sortOrder) ให้ผลคงที่
  for (const [poolName, poolQuests] of pools) {
    const weights = poolQuests.map((q) => Math.max(1, Math.floor(q.poolWeight || 1)));
    let pick = dailyHash(userId, poolName, dayKey) % weights.reduce((a, b) => a + b, 0);
    let chosen = poolQuests[poolQuests.length - 1];
    for (let i = 0; i < poolQuests.length; i++) {
      if (pick < weights[i]) {
        chosen = poolQuests[i];
        break;
      }
      pick -= weights[i];
    }
    candidates.push(chosen);
  }

  const solo = candidates.filter((q) => q.type === 'solo');
  const party = candidates.filter((q) => q.type !== 'solo');
  const pinned = solo.filter((q) => q.alwaysVisible);
  const shuffled = solo
    .filter((q) => !q.alwaysVisible)
    .map((q) => ({ q, h: dailyHash(userId, String(q._id), dayKey) }))
    .sort((a, b) => a.h - b.h)
    .map((x) => x.q);

  // เควส pinned นับเป็นหนึ่งในโควต้า (4 อันของผู้เล่นใหม่ = Check Food + สุ่มอีก 3) แต่ไม่มีทางโดนตัดเอง
  const visibleSolo = [...pinned, ...shuffled].slice(0, Math.max(soloLimit, pinned.length));
  return [...visibleSolo, ...party];
};

module.exports = { selectVisibleQuests };
