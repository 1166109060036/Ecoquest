const mongoose = require('mongoose');

// จองรูป (hash) ไว้ระหว่าง request ส่งหลักฐานกำลังทำงาน — กัน 2 request ส่งรูปเดียวกันพร้อมกันแล้วผ่านทั้งคู่
// ปล่อยตอน response จบ (utils/submissions.js#claimPhoto) ถ้าเซิร์ฟเวอร์ล่มกลางทาง TTL ลบทิ้งเอง
// การกันใช้รูปซ้ำระยะยาวยังเป็น QuestSubmission.photoHash เหมือนเดิม
const PhotoClaimSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true },
  photoHash: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, expires: 120 },
});

PhotoClaimSchema.index({ userId: 1, photoHash: 1 }, { unique: true });

module.exports = mongoose.model('PhotoClaim', PhotoClaimSchema);
