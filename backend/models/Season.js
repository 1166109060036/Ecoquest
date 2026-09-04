const mongoose = require('mongoose');

// ใช้ควบคุมรอบ Season — Rank จะ reset ทุก season แต่ XP ไม่ reset
const SeasonSchema = new mongoose.Schema(
  {
    seasonNumber: {
      type: Number,
      required: true,
      unique: true,
    },
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    isActive: {
      type: Boolean,
      default: false,
      // ควรมี season ที่ isActive: true แค่อันเดียวในระบบ ณ เวลาหนึ่ง
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Season', SeasonSchema);
