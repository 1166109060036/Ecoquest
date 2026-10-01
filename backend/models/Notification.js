const mongoose = require('mongoose');

// การแจ้งเตือนของผู้เล่น — เนื้อหาเขียนสำเร็จรูปมาตั้งแต่ตอนสร้าง (title/message)
// ฝั่งแอพเอาไปโชว์ได้เลย ส่วนไอคอน/รูปเลือกจาก type เอง (ดู lib/models/notification_model.dart)
const NotificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      required: true,
      enum: [
        'quest_complete',
        'fridge_expiring',
        'achievement',
        'friend_request',
        'friend_accepted',
        'streak_milestone',
        // ระบบตรวจสอบภารกิจ (models/QuestSubmission.js) — หลักฐานผ่าน/ไม่ผ่าน
        'quest_approved',
        'quest_rejected',
        // Eco Bingo รายสัปดาห์ (utils/bingo.js) — ครบแถว/ครบการ์ดได้โบนัส
        'bingo',
        // แอดมินถอนโพสต์ออกจากฟีด (routes/feed.js) — บอกเจ้าของว่าทำไม
        'post_removed',
      ],
    },
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      required: true,
    },
    // คีย์กันสร้างซ้ำ — นิยามของแต่ละแบบอยู่ใน utils/notifications.js
    // เช่น 'quest:<questHistoryId>', 'medal:<medalType>', 'expiry:<fridgeItemId>:soon'
    dedupeKey: {
      type: String,
      required: true,
    },
    // ข้อมูลเสริมให้แอพใช้ต่อ (ไม่ใช่ข้อความโชว์) — ตอนนี้ใช้แค่ quest_approved: { points, xp } ให้แอพเล่น
    // เอฟเฟครางวัลบินเข้าป้ายตอนเจอแจ้งเตือนผ่านใบใหม่
    data: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    // null = ยังไม่ได้อ่าน (ใช้นับจุดแดงบนไอคอนกระดิ่ง)
    readAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

// กันไม่ให้เหตุการณ์เดียวกันสร้างแจ้งเตือนซ้ำหลายใบ
// สำคัญมากกับแจ้งเตือนของใกล้หมดอายุ ที่สร้างตอนอ่าน (lazy) ทุกครั้งที่เปิดหน้า Notification
NotificationSchema.index({ userId: 1, dedupeKey: 1 }, { unique: true });

// ใช้ตอนดึงลิสต์ (เรียงล่าสุดขึ้นก่อน)
NotificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', NotificationSchema);
