// สร้างคีย์คงที่ 1 ตัวต่อคู่ผู้ใช้ 2 คน ไม่ว่าใครจะเป็นคนเรียกด้วย id ไหนก่อนก็ตาม
// ใช้ร่วมกันทั้ง Friendship.pairKey (กันขอเพื่อนกันซ้ำ/สวนกัน) และ ChatMessage.channelId
// ของแชทเพื่อน (Phase 4/7) — implementation เดียว ไม่เขียนซ้ำ 2 ที่
const pairKey = (idA, idB) => {
  const [a, b] = [String(idA), String(idB)].sort();
  return `${a}_${b}`;
};

module.exports = { pairKey };
