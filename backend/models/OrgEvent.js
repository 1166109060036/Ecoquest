const mongoose = require('mongoose');

// อีเวนต์ที่บัญชีองค์กร (User.organization.status = approved) สร้างให้ผู้เล่นมาเข้าร่วม (14 ต.ค. 2026)
// ผู้เล่นลงทะเบียนในแอพ -> มางานจริงแล้วสแกน QR ที่องค์กรเปิดบนมือถือ -> ได้แต้ม (routes/org.js)
// แต่ละอีเวนต์มีเควสเงา (Quest type 'org') 1 อัน ให้ awardQuest บันทึกประวัติ/เหรียญ/streak แบบเดียวกับเควสอื่น
const OrgEventSchema = new mongoose.Schema(
  {
    orgUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    questId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Quest',
      required: true,
    },
    title: { type: String, required: true, trim: true, maxlength: 60 },
    description: { type: String, default: '', trim: true, maxlength: 1000 },
    // หมวดเดียวกับเควส (Quest.category) — เช็คอินแล้วนับเข้าเหรียญของหมวดนั้น
    category: {
      type: String,
      enum: ['food_waste', 'recycling', 'plastic', 'community', 'energy'],
      required: true,
    },
    location: { type: String, default: '', trim: true, maxlength: 120 },
    startAt: { type: Date, required: true, index: true },
    endAt: { type: Date, required: true },
    // รับได้สูงสุดกี่คน (รวมคน walk-in ที่สแกนโดยไม่ได้ลงทะเบียนล่วงหน้า)
    capacity: { type: Number, required: true, min: 1 },
    // แต้มที่องค์กรตั้งเอง ในช่วง ORG_POINTS_MIN–MAX (routes/org.js) — XP เท่ากับแต้ม
    points: { type: Number, required: true },
    // scheduled = ปกติ (ยังไม่ถึง/กำลังจัด/จบแล้ว ดูจากเวลา) / cancelled = องค์กรยกเลิกหรือแอดมินปิดองค์กร
    status: {
      type: String,
      enum: ['scheduled', 'cancelled'],
      default: 'scheduled',
      index: true,
    },
    cancelledAt: { type: Date, default: null },
  },
  { timestamps: true }
);

OrgEventSchema.index({ status: 1, endAt: 1, startAt: 1 });

module.exports = mongoose.model('OrgEvent', OrgEventSchema);
