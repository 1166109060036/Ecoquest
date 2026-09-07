const mongoose = require('mongoose');

// Template ของ Quest แต่ละอัน (ไม่ใช่ประวัติการทำ — อันนั้นอยู่ใน QuestHistory)
const QuestSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      default: '',
    },
    category: {
      type: String,
      enum: ['food_waste', 'recycling', 'plastic', 'community'],
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
    // ใช้เฉพาะ party quest — level ขั้นต่ำที่จะสร้าง/host quest นี้ได้
    minLevelToHost: {
      type: Number,
      default: 1,
    },
    // quest ที่ต้อง "ทำอะไรจริงๆ ในแอพ" ก่อนถึงจะกดสำเร็จได้ ให้ใส่ key ไว้ตรงนี้
    // null = quest แบบผู้ใช้กดยืนยันเองว่าทำแล้ว (เชื่อใจผู้ใช้)
    // 'fridge_check' = ต้องบันทึกของในตู้เย็นของวันนี้ก่อน ถึงจะกดสำเร็จได้
    // เพิ่ม key ใหม่ได้เรื่อยๆ — ฝั่งแอพใช้ key นี้ตัดสินว่าจะพาไปหน้าไหนตอนกด Start
    actionKey: {
      type: String,
      default: null,
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
