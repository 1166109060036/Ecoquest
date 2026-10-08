const mongoose = require('mongoose');

// หลักฐานการทำภารกิจ 1 ครั้ง (รูปถ่าย) — กติกาทั้งหมดอยู่ที่ utils/submissions.js
// 7 ต.ค. 2026 (อาจารย์: ให้คนตรวจทุกอันภาระหนัก + ไม่มีคนตรวจ = ไม่ได้แต้มจนหมดกำลังใจ): ส่งรูปแล้วผ่านทันที
// (status 'approved', decidedBy 'instant') ได้แต้มเลย — ผู้เล่นคนอื่นกด "รายงาน" ได้ถ้ารูปดูไม่ได้ทำจริง/ไม่เหมาะ
// แอดมินดูเฉพาะโพสต์ที่ถูกรายงาน: เก็บไว้ / ถอนรูป / ถอนรูป+ยึดแต้มคืน (reports, reportStatus, awards ด้านล่าง)
// 'pending' = ของเก่าจากระบบให้คนตรวจ (28 ก.ย.–7 ต.ค. 2026) — sweep อนุมัติให้หมด ไม่มีที่ไหนสร้างใหม่แล้ว
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
    // ข้อมูลที่กรอกเพิ่มตามฟอร์มของเควส (Quest.proofForm — utils/proofForm.js) เช่น ส่งคืนอะไร / กี่ชิ้น / ร้านไหน
    // ไม่มีฟอร์ม = ไม่มีฟิลด์นี้
    details: {
      choices: { type: [String], default: undefined },
      count: Number,
      place: String,
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
    // instant = ผ่านทันทีตอนส่ง (ระบบปัจจุบัน) / peers, admin, auto = ของเก่าจากระบบให้คนตรวจ
    // admin ยังใช้ตอนแอดมินยึดแต้มคืนจากโพสต์ที่ถูกรายงาน (status เปลี่ยนเป็น rejected)
    decidedBy: {
      type: String,
      enum: ['instant', 'peers', 'admin', 'auto', null],
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
    // แถว QuestHistory ที่ให้ไปจริงของแต่ละคน (party = สมาชิกทุกคน) — ใช้ยึดแต้มคืนตอนแอดมินตัดสินว่ารูปไม่ได้ทำจริง
    // (utils/submissions.js#revokeSubmission) ของเก่าก่อน 7 ต.ค. 2026 ไม่มีฟิลด์นี้ = ยึดคืนไม่ได้ (แค่ถอนรูป)
    awards: {
      type: [
        {
          _id: false,
          userId: mongoose.Schema.Types.ObjectId,
          historyId: mongoose.Schema.Types.ObjectId,
          points: Number,
          xp: Number,
          checkInDay: Boolean, // เช็คอินวันระหว่างทาง — ไม่ได้นับเป็นทำเควสสำเร็จ (totalQuestsCompleted)
        },
      ],
      default: [],
    },
    // ---- รายงานโพสต์ (routes/feed.js POST /:id/report) ----
    // 1 คน 1 ครั้ง / บัญชีจริงเท่านั้น (guest สร้างได้ไม่จำกัด กันรุมรายงานให้โพสต์หาย)
    reports: {
      type: [
        {
          _id: false,
          userId: mongoose.Schema.Types.ObjectId,
          reason: { type: String, enum: ['not_done', 'personal_info', 'inappropriate', 'other'] },
          createdAt: Date,
        },
      ],
      default: [],
    },
    // open = รอแอดมินดู / kept = แอดมินดูแล้วไม่มีปัญหา / removed = ถอนรูป แต้มอยู่ / revoked = ถอนรูป + ยึดแต้มคืน
    reportStatus: {
      type: String,
      enum: ['open', 'kept', 'removed', 'revoked', null],
      default: null,
    },
    // รายงานครบ REPORTS_TO_HIDE คน = ซ่อนจากฟีดไว้ก่อนจนกว่าแอดมินดู (แอดมินกด "เก็บไว้" = กลับมาโชว์)
    hiddenByReports: { type: Boolean, default: false },
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
// คิวโพสต์ที่ถูกรายงานของแอดมิน (routes/reviews.js)
QuestSubmissionSchema.index({ reportStatus: 1, updatedAt: 1 });

module.exports = mongoose.model('QuestSubmission', QuestSubmissionSchema);
