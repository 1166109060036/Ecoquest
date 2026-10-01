const mongoose = require('mongoose');

// หลักฐานการทำภารกิจ 1 ครั้ง (รูปถ่าย) ที่รอผู้เล่นคนอื่น/แอดมินตรวจ — อาจารย์ให้เปลี่ยนจาก "ผู้ใช้กดยืนยันเอง"
// เป็นระบบตรวจสอบ (28 ก.ย. 2026) กติกาทั้งหมดอยู่ที่ utils/submissions.js:
//   ผ่าน 2 คน = approved / ไม่ผ่าน 2 คน = rejected / แอดมินโหวตครั้งเดียวตัดสินเลย / ไม่มีข้อสรุปใน 48 ชม. = ตัดสินอัตโนมัติ
// แต้ม/XP/CO2 (QuestHistory) เกิดตอน approved เท่านั้น — Daily Streak นับตั้งแต่ตอนส่ง (ทำกิจกรรมวันนั้นจริง)
//
// kind:
//   quest    = เควส solo ปกติ
//   check_in = เควสหลายวัน (Food Saver) 1 วัน — checkIn.finished = วันสุดท้าย (ผ่าน = รางวัลเต็ม)
//   party    = อีเวนต์ปาร์ตี้ หัวหน้าส่งรูปกลุ่ม 1 รูป ผ่าน = สมาชิกทุกคนใน memberIds ได้รางวัล
//
// ส่วนฟีดชุมชน (routes/feed.js) ใช้ submission ที่ approved ตัวเดียวกันนี้ + cheers
const QuestSubmissionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    questId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Quest',
      required: true,
    },
    kind: {
      type: String,
      enum: ['quest', 'check_in', 'party'],
      default: 'quest',
    },
    // ---- เฉพาะ party ----
    partyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Party',
      default: null,
    },
    // สมาชิกตอนส่ง (รวมหัวหน้า) — ใครออกจากห้องระหว่างรอตรวจก็ยังได้รางวัล เพราะร่วมอีเวนต์จริงแล้ว
    // สมาชิกห้องนี้ตรวจรูปของห้องตัวเองไม่ได้
    memberIds: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
    },
    // ---- เฉพาะ check_in ----
    checkIn: {
      daysDone: Number,
      durationDays: Number,
      finished: Boolean,
    },
    // ---- รูปหลักฐาน ---- เก็บเป็น Buffer ในเอกสารเลยแบบรูปในตู้เย็น (FridgeItem.photoData) — Render free tier
    // เก็บไฟล์ถาวรไม่ได้ เสิร์ฟผ่าน GET /api/submissions/:id/photo (ไม่ต้อง login แบบรูปโปรไฟล์)
    // ⚠️ ไม่ required — ไม่ผ่านการตรวจ/ผ่านแล้วข้ามวัน ถูกลบทิ้ง (purgeExpiredPhotos ใน utils/submissions.js)
    // เอกสารที่ไม่มีรูปต้อง save ได้
    // ตอนสร้างใหม่ route บังคับให้มีรูปเองอยู่แล้ว (routes/quests.js, routes/party.js)
    photoData: {
      type: Buffer,
    },
    photoContentType: {
      type: String,
      required: true,
    },
    // sha256 ของรูป — ส่งรูปเดิมซ้ำของตัวเองไม่ได้ (กันถ่ายครั้งเดียวใช้ทำเควสซ้ำได้ไม่จำกัด)
    photoHash: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    approvals: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
    },
    rejections: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
    },
    decidedBy: {
      type: String,
      enum: ['peers', 'admin', 'auto', null],
      default: null,
    },
    decidedAt: {
      type: Date,
      default: null,
    },
    // แต้ม/XP ที่ได้จริงตอนผ่าน (ของคนส่ง — party คือของหัวหน้า) ให้ฟีด/หน้า Progress โชว์ได้โดยไม่ต้องคำนวณใหม่
    reward: {
      points: { type: Number, default: 0 },
      xp: { type: Number, default: 0 },
      // ตัวคูณ Daily Variety Combo ที่ใช้ตอนให้รางวัล (utils/combo.js) — 1 = ไม่มีคอมโบ
      comboMultiplier: { type: Number, default: 1 },
    },
    // ฟีดชุมชน — ใครกด cheer ให้บ้าง (1 คน 1 ครั้ง)
    cheers: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
    },
    // ถอนออกจากฟีด (routes/feed.js DELETE /:id) — แอดมินหรือเจ้าของโพสต์ เช่น รูปมีข้อมูลส่วนตัว
    // ลบรูปทิ้งทันที แต่ไม่ยึดแต้มคืน (ทำเควสจริงแล้ว แค่รูปไม่เหมาะจะโชว์)
    removedFromFeed: { type: Boolean, default: false },
    removedAt: { type: Date, default: null },
    removedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { timestamps: true }
);

QuestSubmissionSchema.index({ status: 1, createdAt: -1 });
QuestSubmissionSchema.index({ userId: 1, createdAt: -1 });
QuestSubmissionSchema.index({ userId: 1, photoHash: 1 });
// Today Feed + ลบรูปของที่ผ่านแล้วข้ามวัน (routes/feed.js, utils/submissions.js#purgeExpiredPhotos)
QuestSubmissionSchema.index({ status: 1, decidedAt: -1 });

module.exports = mongoose.model('QuestSubmission', QuestSubmissionSchema);
