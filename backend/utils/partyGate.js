// รวม logic กันปั๊มคะแนนจากเควส Party ไว้ไฟล์เดียว — แนวเดียวกับ progression.js/upgrades.js/inventory.js
//
// ปัญหาเดิม: สร้างห้อง -> กด "Complete Event" ทันที -> ได้คะแนนโดยไม่ต้องทำอะไรจริง เพราะ latch เดิมเช็คแค่
// สถานะห้องกับว่าเป็นหัวหน้าไหม ไม่เช็ค eventDate หรือจำนวนคนเลย
//
// ทางแก้: เพิ่มสถานะ 'started' คั่นกลาง (ดู models/Party.js) ต้องกด "Start Event" ก่อนถึงจะกด "Complete
// Event" ได้ — กด Start ได้ต่อเมื่อถึงเวลานัด (eventDate) แล้ว และสมาชิกครบตาม requiredMembers และ
// กด Complete ได้ต่อเมื่อผ่านมาแล้วอย่างน้อย START_TO_COMPLETE_MS นับจากตอนกด Start

// ห้องเก่าที่ยังมี capacity: 0 ค้างอยู่ใน DB (ก่อนบังคับขั้นต่ำ 2 คน) ใช้เกณฑ์นี้แทน
const MIN_PARTY_MEMBERS = 2;

// ต้องรอ 15 นาทีหลังกด Start ถึงจะกด Complete ได้ — กันกดเริ่ม-กดจบรวดเดียวไม่ต่างจากเดิม
const START_TO_COMPLETE_MS = 15 * 60 * 1000;

// จำนวนคนที่ต้องมีถึงจะเริ่มได้ — ห้องใหม่บังคับ capacity >= 2 เสมอ (ดู routes/party.js POST /)
// capacity 0 เหลืออยู่ได้แค่ห้องเก่าก่อนหน้านี้เท่านั้น เลย fallback เป็น MIN_PARTY_MEMBERS
const requiredMembers = (party) => (party.capacity > 0 ? party.capacity : MIN_PARTY_MEMBERS);

// เช็คว่ากด "Start Event" ได้ไหมตอนนี้ — คืน { ok, reason } เสมอ (reason เป็น null ตอน ok: true)
// ต้องเรียกก่อน latch เปลี่ยนสถานะทุกครั้ง ห้ามเช็คทีหลัง ไม่งั้นจะได้ห้องที่ flip สถานะไปแล้วแต่ไม่ผ่านเงื่อนไข
const canStart = (party, memberCount, now = new Date()) => {
  if (party.status !== 'open') {
    return { ok: false, reason: 'This event is not open anymore' };
  }
  if (party.eventDate.getTime() > now.getTime()) {
    return { ok: false, reason: `This event starts at ${party.eventDate.toISOString()}` };
  }
  const needed = requiredMembers(party);
  if (memberCount < needed) {
    return { ok: false, reason: `Waiting for more members (${memberCount}/${needed})` };
  }
  return { ok: true, reason: null };
};

// เช็คว่ากด "Complete Event" ได้ไหมตอนนี้
const canComplete = (party, now = new Date()) => {
  if (party.status === 'open') {
    return { ok: false, reason: 'Start the event first' };
  }
  if (party.status !== 'started') {
    return { ok: false, reason: 'This event is already completed' };
  }
  const readyAt = party.startedAt.getTime() + START_TO_COMPLETE_MS;
  if (now.getTime() < readyAt) {
    const remainingMs = readyAt - now.getTime();
    return { ok: false, reason: `Available in ${Math.ceil(remainingMs / 60000)} more minute(s)` };
  }
  return { ok: true, reason: null };
};

module.exports = { MIN_PARTY_MEMBERS, START_TO_COMPLETE_MS, requiredMembers, canStart, canComplete };
