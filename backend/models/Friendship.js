const mongoose = require('mongoose');

// เอกสารเดียวต่อ "คู่เพื่อน" 1 คู่ (ไม่ใช่ log คำขอ) — ไม่ว่าใครขอใครก่อน มีแค่แถวเดียวเสมอ
// requesterId/recipientId บอกว่าใครเป็นคนกดขอก่อน (ใช้แยกทิศทางลิสต์ incoming/outgoing)
// status เปลี่ยนจาก pending -> accepted เมื่อฝั่ง recipient กด accept
// ปฏิเสธ/ยกเลิกคำขอ = ลบแถวทิ้งไปเลย (ไม่เก็บ log ประวัติ แนวเดียวกับที่ /leave ของ Party ลบ
// PartyMember ทิ้งตรงๆ ไม่ soft-delete)
const FriendshipSchema = new mongoose.Schema(
  {
    requesterId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    recipientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // pairKey(requesterId, recipientId) จาก utils/friendKey.js — unique index ด้านล่างใช้ตัวนี้
    // เป็นตัวกันคำขอซ้ำ/สวนกัน (2 คนกดขอกันพร้อมกันพอดี) ไม่ใช่ requesterId+recipientId ตรงๆ
    // เพราะต้องกันได้ทั้ง 2 ทิศทาง
    pairKey: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      enum: ['pending', 'accepted'],
      default: 'pending',
      index: true,
    },
    respondedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

// คู่เดียวกันมีได้แค่ 1 แถวเท่านั้น ไม่ว่าจะ pending หรือ accepted — ถ้ามีคน 2 คนกดขอเพื่อนกัน
// พร้อมกันพอดี (คนละทิศทาง) request ที่ 2 จะชน error 11000 แทนสร้างซ้ำ (ดู routes/friends.js
// ที่จับ error นี้แล้ว auto-accept คำขอแรกให้เลยแทนตอบ error)
FriendshipSchema.index({ pairKey: 1 }, { unique: true });

// สำหรับลิสต์คำขอที่รอตอบ (เข้า/ออก) ของแต่ละคน
FriendshipSchema.index({ recipientId: 1, status: 1 });
FriendshipSchema.index({ requesterId: 1, status: 1 });

module.exports = mongoose.model('Friendship', FriendshipSchema);
