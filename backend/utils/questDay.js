// ตัดวันของ quest รายวัน (และตอนนี้รวมถึง party quest ที่ทำซ้ำได้วันละครั้ง) — default = UTC+9
// (ญี่ปุ่น/Ebetsu City ซึ่งเป็นกลุ่มผู้ใช้จริง)
// ห้ามใช้เวลาเครื่อง server เฉยๆ เพราะ Render รันเป็น UTC ถ้าใช้เวลาเครื่อง
// quest จะไปรีเซ็ตตอน 9 โมงเช้าเวลาญี่ปุ่นแทนที่จะเป็นเที่ยงคืน
//
// แยกออกมาจาก routes/quests.js เพราะ routes/party.js ก็ต้องเช็ค "วันนี้ทำไปหรือยัง" เหมือนกัน
const QUEST_DAY_UTC_OFFSET_HOURS = Number(process.env.QUEST_DAY_UTC_OFFSET_HOURS ?? 9);

// เที่ยงคืนของ "วันนี้" ตามโซนเวลาข้างบน คืนออกมาเป็นเวลา UTC จริงเพื่อเอาไป query Mongo
// วิธีคิด: เลื่อนเวลาปัจจุบันไปเป็นเวลาท้องถิ่นก่อน -> ตัดเอาเฉพาะวันที่ -> เลื่อนกลับเป็น UTC
const startOfToday = () => {
  const offsetMs = QUEST_DAY_UTC_OFFSET_HOURS * 60 * 60 * 1000;
  const localNow = new Date(Date.now() + offsetMs);
  const localMidnight = Date.UTC(
    localNow.getUTCFullYear(),
    localNow.getUTCMonth(),
    localNow.getUTCDate()
  );
  return new Date(localMidnight - offsetMs);
};

// คีย์ของ "วันนี้" ในรูปแบบ YYYY-MM-DD ตามโซนเวลาที่ใช้ตัดวัน
const todayKey = () => startOfToday().toISOString().slice(0, 10);

module.exports = { QUEST_DAY_UTC_OFFSET_HOURS, startOfToday, todayKey };
