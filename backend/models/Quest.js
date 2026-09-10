const mongoose = require('mongoose');

// Template ของ Quest แต่ละอัน (ไม่ใช่ประวัติการทำ — อันนั้นอยู่ใน QuestHistory)
const QuestSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
    },
    // บรรทัดสั้นใต้ชื่อ quest (เช่น "Food Waste Quest") — โชว์บนการ์ดและหน้ารายละเอียด
    description: {
      type: String,
      default: '',
    },
    // ข้อความอธิบายยาวๆ ในกล่อง "Quest Detail" ของหน้ารายละเอียด
    detail: {
      type: String,
      default: '',
    },
    // key ของรูปปก — ฝั่งแอพจะไปหาไฟล์ lib/utils/assets/questimg/<imageKey>.png เอง
    // (เก็บเป็น key ไม่ใช่ path เต็ม เพราะ backend ไม่ควรรู้โครงสร้างโฟลเดอร์ของแอพ)
    imageKey: {
      type: String,
      default: null,
    },
    category: {
      type: String,
      // 'energy' เพิ่มเข้ามาทีหลังตอน seed quest จริง (เควสประหยัดไฟ/ถอดปลั๊ก)
      // ถ้าเพิ่มหมวดใหม่ อย่าลืมเพิ่มไอคอนใน _categoryVisual ของ profile_page.dart ด้วย
      enum: ['food_waste', 'recycling', 'plastic', 'community', 'energy'],
      required: true,
    },
    type: {
      type: String,
      enum: ['solo', 'party'],
      required: true,
      default: 'solo',
    },
    difficulty: {
      type: String,
      enum: ['easy', 'medium', 'hard'],
      required: true,
    },
    impact: {
      type: String,
      enum: ['low', 'medium', 'high'],
      required: true,
    },
    // คำนวณไว้ล่วงหน้าตอนสร้าง quest จาก difficulty + impact
    scorePoints: {
      type: Number,
      required: true,
    },
    xpReward: {
      type: Number,
      default: 0,
    },
    // ปริมาณ CO2 ที่ช่วยลดได้เมื่อทำ quest นี้สำเร็จ (kgCO2e)
    // ใช้รวมเป็นสถิติ "CO2 Saved" ในหน้า Profile — ตอน seed quest จริงต้องใส่ค่านี้ด้วย
    co2SavedKg: {
      type: Number,
      default: 0,
    },
    // ใช้เฉพาะ party quest — level ขั้นต่ำที่จะสร้างห้อง (Party) จาก quest นี้ได้
    // เช็คจริงตอน POST /api/party ใน backend/routes/party.js
    minLevelToHost: {
      type: Number,
      default: 1,
    },

    // ---- ใช้เฉพาะ party quest (type: 'party') — quest เดี่ยวไม่ต้องมีค่าพวกนี้ ----
    // ⚠️ ไม่มี eventDate ที่นี่แล้ว — วัน-เวลานัดเจอกันย้ายไปอยู่ที่ Party.eventDate
    // (แต่ละห้องนัดคนละเวลากันได้ ถึงจะสร้างจาก quest template เดียวกัน)
    //
    // location/capacity ที่เหลือด้านล่างนี้เป็นแค่ "ค่า default" ให้ฟอร์มสร้างห้องดึงไปเติมให้เอง
    // ผู้สร้างห้องแก้เป็นค่าอื่นได้ ค่าจริงที่ใช้งานอยู่ที่ Party.location / Party.capacity
    location: {
      type: String,
      default: '',
    },
    capacity: {
      type: Number,
      default: 0,
    },
    // quest ที่ต้อง "ทำอะไรจริงๆ ในแอพ" ก่อนถึงจะกดสำเร็จได้ ให้ใส่ key ไว้ตรงนี้
    // null = quest แบบผู้ใช้กดยืนยันเองว่าทำแล้ว (เชื่อใจผู้ใช้)
    // 'fridge_check' = ต้องบันทึกของในตู้เย็นของวันนี้ก่อน ถึงจะกดสำเร็จได้
    // เพิ่ม key ใหม่ได้เรื่อยๆ — ฝั่งแอพใช้ key นี้ตัดสินว่าจะพาไปหน้าไหนตอนกด Start
    actionKey: {
      type: String,
      default: null,
    },
    // quest ที่อยู่ "กลุ่มสุ่ม" เดียวกัน จะถูกสุ่มโชว์แค่อันเดียวต่อวัน
    // เช่น 'food_saver' -> Food Saver 1/3/7 Days จะโผล่วันละอันเท่านั้น ไม่ได้โผล่พร้อมกันทั้ง 3
    // null = โชว์ตลอด ไม่เข้ากลุ่มสุ่ม
    randomPool: {
      type: String,
      default: null,
      index: true,
    },
    // true = ทำซ้ำได้วันละครั้ง (เช็คจาก QuestHistory ของวันนั้น)
    // false = ไม่จำกัด (ยังไม่มี quest แบบทำได้ครั้งเดียวตลอดชีพ ถ้าจะมีค่อยเพิ่มฟิลด์ทีหลัง)
    isDaily: {
      type: Boolean,
      default: false,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// ตาราง point อ้างอิงตามเอกสาร: easy=5/medium=10/hard=15, low=5/medium=10/high=15
const DIFFICULTY_POINTS = { easy: 5, medium: 10, hard: 15 };
const IMPACT_POINTS = { low: 5, medium: 10, high: 15 };

// helper ให้ backend เรียกใช้คำนวณ scorePoints อัตโนมัติตอนสร้าง quest ใหม่
QuestSchema.statics.calculateScore = function (difficulty, impact) {
  return (DIFFICULTY_POINTS[difficulty] || 0) + (IMPACT_POINTS[impact] || 0);
};

module.exports = mongoose.model('Quest', QuestSchema);
