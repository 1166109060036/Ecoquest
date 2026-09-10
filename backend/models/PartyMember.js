const mongoose = require('mongoose');

// สมาชิกของห้อง (Party) — คนที่กดเข้าร่วมห้องที่มีคนสร้างไว้แล้ว
// เควส (quest template) เข้าถึงได้ผ่าน party.questId ไม่ต้องเก็บซ้ำที่นี่
const PartyMemberSchema = new mongoose.Schema(
  {
    partyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Party',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // คนแรกที่สร้างห้องเป็นหัวหน้า ถ้าหัวหน้าออกจากห้องก่อนอีเวนต์จบ ตำแหน่งจะตกไปคนถัดไปตาม joinedAt
    isLeader: {
      type: Boolean,
      default: false,
    },
    joinedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// คนเดียวเข้าห้องเดียวกันซ้ำไม่ได้ (การเช็ค "อยู่คนละห้องพร้อมกันไม่ได้" ทำที่ route แทน
// เพราะต้องใช้ userId เดี่ยวๆ ค้นหา ไม่เกี่ยวกับ partyId)
PartyMemberSchema.index({ partyId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('PartyMember', PartyMemberSchema);
