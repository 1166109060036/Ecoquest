const mongoose = require('mongoose');

// ห้อง (Party) = สิ่งที่ผู้เล่นกด "สร้าง" ขึ้นมาจาก party quest ที่มีอยู่แล้ว
// เหมือนห้องในเกมที่คนอื่นกดเข้าร่วมได้ — 1 quest template สร้างได้หลายห้อง คนละเวลา/สถานที่กัน
// (สมาชิกของห้องอยู่ที่ PartyMember.js แยกออกไป เหมือนเดิม แต่ตอนนี้ผูกกับ partyId แทน questId)
const PartySchema = new mongoose.Schema(
  {
    questId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Quest',
      required: true,
      index: true,
    },
    // หัวหน้าห้องคนปัจจุบัน — ย้ายไปคนอื่นได้ถ้าหัวหน้าเดิมออกจากห้องก่อนอีเวนต์จบ
    leaderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // ชื่อห้องที่ผู้สร้างตั้งเอง (ไม่ใช่ชื่อ quest) เช่น "เก็บขยะเช้าวันเสาร์"
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 60,
    },
    // วัน-เวลาที่นัดเจอกันจริงของห้องนี้ — แยกจาก quest template เพราะแต่ละห้องนัดคนละเวลากันได้
    eventDate: {
      type: Date,
      required: true,
    },
    location: {
      type: String,
      default: '',
    },
    // รับได้สูงสุดกี่คน — 0 = ไม่จำกัด
    capacity: {
      type: Number,
      default: 0,
    },
    // open = ยังรับสมาชิก/รอทำอีเวนต์อยู่, completed = หัวหน้ากดจบแล้ว รอสมาชิกกดออกเอง
    status: {
      type: String,
      enum: ['open', 'completed'],
      default: 'open',
      index: true,
    },
    completedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Party', PartySchema);
