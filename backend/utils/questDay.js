// ตัดวันของ quest รายวัน (และตอนนี้รวมถึง party quest ที่ทำซ้ำได้วันละครั้ง) — default = UTC+9
// (ญี่ปุ่น/Ebetsu City ซึ่งเป็นกลุ่มผู้ใช้จริง)
// ห้ามใช้เวลาเครื่อง server เฉยๆ เพราะ Render รันเป็น UTC ถ้าใช้เวลาเครื่อง
// quest จะไปรีเซ็ตตอน 9 โมงเช้าเวลาญี่ปุ่นแทนที่จะเป็นเที่ยงคืน
//
// แยกออกมาจาก routes/quests.js เพราะ routes/party.js ก็ต้องเช็ค "วันนี้ทำไปหรือยัง" เหมือนกัน
const QUEST_DAY_UTC_OFFSET_HOURS = Number(process.env.QUEST_DAY_UTC_OFFSET_HOURS ?? 9);

const OFFSET_MS = QUEST_DAY_UTC_OFFSET_HOURS * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

// เที่ยงคืนของวันที่ `date` อยู่ ตามโซนเวลาข้างบน คืนออกมาเป็นเวลา UTC จริงเพื่อเอาไป query Mongo
// วิธีคิด: เลื่อนเวลาไปเป็นเวลาท้องถิ่นก่อน -> ตัดเอาเฉพาะวันที่ -> เลื่อนกลับเป็น UTC
const startOfDayFor = (date) => {
  const local = new Date(new Date(date).getTime() + OFFSET_MS);
  const localMidnight = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  return new Date(localMidnight - OFFSET_MS);
};

const startOfToday = () => startOfDayFor(Date.now());

// ต้นสัปดาห์ = เที่ยงคืนวันจันทร์ (เวลาญี่ปุ่น) ของสัปดาห์ที่ `date` อยู่ — Eco Bingo รายสัปดาห์ (utils/bingo.js)
const startOfWeekFor = (date) => {
  const dayStart = startOfDayFor(date);
  const dow = (new Date(dayStart.getTime() + OFFSET_MS).getUTCDay() + 6) % 7; // จันทร์ = 0
  return new Date(dayStart.getTime() - dow * DAY_MS);
};

// คีย์ของสัปดาห์ = วันที่ (เวลาท้องถิ่น) ของวันจันทร์ รูปแบบ YYYY-MM-DD
const weekKeyFor = (date) => new Date(startOfWeekFor(date).getTime() + OFFSET_MS).toISOString().slice(0, 10);

// คีย์ของ "วันนี้" ในรูปแบบ YYYY-MM-DD ตามโซนเวลาที่ใช้ตัดวัน
const todayKey = () => startOfToday().toISOString().slice(0, 10);

// คีย์ของ "เมื่อวาน" รูปแบบเดียวกับ todayKey — ใช้เช็คว่าเควสหลายวันเช็คอินติดกันหรือไม่
const yesterdayKey = () =>
  new Date(startOfToday().getTime() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

module.exports = {
  QUEST_DAY_UTC_OFFSET_HOURS,
  DAY_MS,
  startOfDayFor,
  startOfToday,
  startOfWeekFor,
  weekKeyFor,
  todayKey,
  yesterdayKey,
};
