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
    // ใช้เฉพาะ party quest — level ขั้นต่ำที่จะสร้าง/host quest นี้ได้
    minLevelToHost: {
      type: Number,
      default: 1,
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
