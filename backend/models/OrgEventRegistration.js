const mongoose = require('mongoose');

// การลงทะเบียน/เช็คอินอีเวนต์องค์กร 1 แถวต่อคนต่ออีเวนต์ (models/OrgEvent.js)
// registered = ลงทะเบียนแล้ว ยังไม่ได้สแกน / attended = สแกน QR ที่งานแล้ว ได้แต้มแล้ว
// ยกเลิกการลงทะเบียน = ลบแถวทิ้ง (ยกเลิกได้เฉพาะก่อนงานเริ่มและยังไม่ได้เช็คอิน)
const OrgEventRegistrationSchema = new mongoose.Schema(
  {
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'OrgEvent',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['registered', 'attended'],
      default: 'registered',
    },
    attendedAt: { type: Date, default: null },
    // ผลรางวัลที่ได้จริงตอนเช็คอิน (หลังคูณ upgrade) + แถวประวัติ — ให้องค์กร/ผู้เล่นดูย้อนหลังได้
    historyId: { type: mongoose.Schema.Types.ObjectId, ref: 'QuestHistory', default: null },
    pointsEarned: { type: Number, default: 0 },
    xpEarned: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// คนเดียวลงทะเบียน/เช็คอินอีเวนต์เดียวกันซ้ำไม่ได้ — กันสแกนรัวๆ ได้แต้มซ้ำอีกชั้นนอกจาก CAS ใน route
OrgEventRegistrationSchema.index({ eventId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('OrgEventRegistration', OrgEventRegistrationSchema);
