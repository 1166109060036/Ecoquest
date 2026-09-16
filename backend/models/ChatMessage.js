const mongoose = require('mongoose');

// ข้อความแชท — คอลเลกชันเดียวแยกด้วย channelType เหมือน Notification.js แยกด้วย type
// (ไม่ทำ 3 model แยกกันสำหรับโลก/ปาร์ตี้/เพื่อน เพราะ shape เหมือนกันหมด ต่างกันแค่ channelId หมายถึง
// อะไร):
//   channelType 'world'  -> channelId คงที่ 'world' เสมอ
//   channelType 'party'  -> channelId = Party._id.toString()
//   channelType 'friend' -> channelId = pairKey(userA, userB) จาก utils/friendKey.js (คีย์เดียวกับที่
//                           Friendship.pairKey ใช้ — implementation เดียว ไม่เขียนซ้ำ)
//
// ⚠️ ส่งข้อความทำได้ทางเดียวคือผ่าน socket (chat:send ใน sockets/index.js) — ไม่มี POST REST สำหรับ
// เขียนข้อความ REST มีไว้แค่ดึงประวัติ (routes/chat.js) เพราะมีทางเขียนทางเดียวชัดเจน ไม่ต้องกังวลว่า
// ข้อความจะมาจาก 2 ทางแล้ว sync กันไม่ตรง
const ChatMessageSchema = new mongoose.Schema(
  {
    channelType: {
      type: String,
      required: true,
      enum: ['world', 'party', 'friend'],
      index: true,
    },
    channelId: {
      type: String,
      required: true,
      index: true,
    },
    fromUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    text: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000,
    },
  },
  { timestamps: true }
);

// ใช้ paginate ประวัติของแต่ละห้อง (ล่าสุดขึ้นก่อน) — คีย์หลักที่ query ทุกครั้งที่ดึงประวัติ
ChatMessageSchema.index({ channelType: 1, channelId: 1, createdAt: -1 });

module.exports = mongoose.model('ChatMessage', ChatMessageSchema);
