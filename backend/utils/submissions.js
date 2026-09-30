// ระบบตรวจสอบภารกิจ (28 ก.ย. 2026 — อาจารย์ให้เปลี่ยนจากผู้ใช้กดยืนยันเอง) ดู models/QuestSubmission.js
//
// กติกา (ผู้ใช้เลือกแล้ว):
//   ผู้เล่นคนอื่นกดผ่าน APPROVALS_NEEDED คน = ผ่าน / กดไม่ผ่าน REJECTIONS_NEEDED คน = ไม่ผ่าน
//   แอดมิน (ADMIN_EMAILS) โหวตครั้งเดียวตัดสินเลย
//   ตรวจได้เฉพาะบัญชีจริง — guest โหวตไม่ได้ (กันสร้าง guest หลายบัญชีมาอนุมัติตัวเอง, ผู้ใช้กำหนด 30 ก.ย. 2026)
//   ไม่มีข้อสรุปใน ESCALATE_AFTER_MS (48 ชม.) = ส่งต่อให้แอดมินตัดสินคนเดียว ผู้เล่นทั่วไปโหวตต่อไม่ได้แล้ว
//   (เดิมตัดสินอัตโนมัติ "ผ่านถ้าเสียงผ่าน >= ไม่ผ่าน" ซึ่งไม่มีใครตรวจเลย 0-0 ก็ผ่าน = ส่งรูปอะไรก็ได้แล้วรอ 2 วัน)
// แต้ม/XP/CO2 ได้ตอนผ่านเท่านั้น (utils/questRewards.js#awardQuest)
const crypto = require('crypto');
const QuestSubmission = require('../models/QuestSubmission');
const QuestHistory = require('../models/QuestHistory');
const QuestProgress = require('../models/QuestProgress');
const Quest = require('../models/Quest');
const Party = require('../models/Party');
const { awardQuest } = require('./questRewards');
const { notifyQuestApproved, notifyQuestRejected } = require('./notifications');
const { avatarUrlFor, cosmeticsFor } = require('./avatar');
const { startOfToday } = require('./questDay');

// ฟิลด์สาธารณะของผู้ใช้ที่ populate มากับ submission — allow-list เดียวกับ routes/friends.js (ห้ามหลุด email ฯลฯ)
const PUBLIC_USER_FIELDS = 'displayName level avatarContentType avatarUpdatedAt cosmetics';
const toPublicUser = (u) => ({
  id: u._id,
  displayName: u.displayName,
  level: u.level,
  avatarUrl: avatarUrlFor(u),
  cosmetics: cosmeticsFor(u),
});
// ฟิลด์เควสที่ payload ใช้
const QUEST_FIELDS = 'title detail category co2eEstimateKg durationDays';

const APPROVALS_NEEDED = 2;
const REJECTIONS_NEEDED = 2;
const ESCALATE_AFTER_MS = 48 * 60 * 60 * 1000;

// ส่งมาเกิน 48 ชม. แล้วยังไม่มีข้อสรุป = รอแอดมิน — คิดจาก createdAt ตรงๆ ไม่มีฟิลด์/งานเบื้องหลังต้องอัปเดต
const escalationCutoff = () => new Date(Date.now() - ESCALATE_AFTER_MS);
const isEscalated = (s) => s.status === 'pending' && Boolean(s.createdAt) && s.createdAt < escalationCutoff();

const photoHashOf = (buffer) => crypto.createHash('sha256').update(buffer).digest('hex');

// รูปเดิมของตัวเองส่งซ้ำไม่ได้ (ยกเว้นครั้งก่อนไม่ผ่าน — ถ่ายใหม่แต่ได้รูปเดิมไม่มีทางเกิด ส่วนส่งรูปเดิมที่ไม่ผ่าน
// ซ้ำก็ควรไม่ผ่านอีกอยู่ดี เลยกันทุกสถานะ)
const isDuplicatePhoto = async (userId, photoHash) =>
  Boolean(await QuestSubmission.exists({ userId, photoHash }));

// ผู้ใช้ปลายทางที่ได้ผลของ submission นี้ (party = สมาชิกทุกคน, อื่นๆ = คนส่ง)
const recipientsOf = (submission) =>
  submission.kind === 'party' && submission.memberIds.length > 0
    ? submission.memberIds
    : [submission.userId];

// ตัดสิน 1 ครั้งแบบ compare-and-swap (pending -> approved/rejected) — โหวตพร้อมกันหลายคน/แอดมินกดซ้อนกับ
// sweep อัตโนมัติ มีแค่ request เดียวที่ชนะ ได้รางวัลครั้งเดียวแน่นอน (แพทเทิร์นเดียวกับ /party/start)
// คืน submission หลังตัดสิน หรือ null ถ้ามีคนตัดสินไปแล้ว
const finalizeSubmission = async (submissionId, status, decidedBy) => {
  const submission = await QuestSubmission.findOneAndUpdate(
    { _id: submissionId, status: 'pending' },
    { $set: { status, decidedBy, decidedAt: new Date() } },
    { new: true, projection: { photoData: 0 } }
  );
  if (!submission) return null;

  // อ่าน template แม้เควสถูกปิดไปแล้วก็ยังให้รางวัล (ทำไปแล้วจริงก่อนปิด) — ถูกลบทิ้งจริงเท่านั้นถึงข้าม
  const quest = await Quest.findById(submission.questId);
  if (!quest) return submission;

  const checkIn = submission.kind === 'check_in' ? submission.checkIn : null;

  if (status === 'approved') {
    if (checkIn && !checkIn.finished) {
      // เช็คอินวันระหว่างทาง — ไม่ได้แต้ม แต่ได้แถว checkIn ที่นับ CO2 ของวันนั้น (ดู QuestHistory.checkIn)
      await QuestHistory.create({
        userId: submission.userId,
        questId: quest._id,
        pointsEarned: 0,
        xpEarned: 0,
        checkIn: true,
        completedAt: submission.createdAt,
      });
      await safeNotify(() =>
        notifyQuestApproved(submission.userId, quest, submission._id, { points: 0, xp: 0 }, checkIn)
      );
      return submission;
    }

    // เควสปกติ / วันสุดท้ายของเควสหลายวัน / ปาร์ตี้ (ทุกคนในห้อง)
    for (const userId of recipientsOf(submission)) {
      const result = await awardQuest(userId, quest, { completedAt: submission.createdAt });
      if (!result) continue; // user ถูกลบไปแล้ว
      if (String(userId) === String(submission.userId)) {
        await QuestSubmission.updateOne(
          { _id: submission._id },
          { $set: { reward: { points: result.reward.points, xp: result.reward.xp } } }
        );
        submission.reward = { points: result.reward.points, xp: result.reward.xp };
      }
      await safeNotify(() =>
        notifyQuestApproved(userId, quest, submission._id, result.reward, checkIn)
      );
    }

    if (submission.kind === 'party' && submission.partyId) {
      await Party.updateOne(
        { _id: submission.partyId, status: 'reviewing' },
        { $set: { status: 'completed', completedAt: new Date() } }
      );
    }
    return submission;
  }

  // ---- ไม่ผ่าน ----
  // ลบรูปทิ้งทันที — รูปที่ไม่ผ่านไม่มีใครต้องดูอีกแล้ว (ไม่ขึ้นฟีด ไม่อยู่ในคิว) และอาจเป็นรูปที่ไม่ควรเก็บไว้ (เจอจริง:
  // ผู้ทดสอบเลือกรูปสลิปโอนเงินที่มีชื่อ/เลขบัญชีส่งมา) คง photoHash ไว้ กันส่งรูปเดิมซ้ำเหมือนเดิม
  await purgeRejectedPhoto(submission._id);
  if (checkIn && !checkIn.finished) {
    // เช็คอินวันระหว่างทางไม่ผ่าน = นับใหม่วันที่ 1 (เหมือนลืมเช็คอิน — ผู้ใช้ตัดสินใจแล้ว)
    await QuestProgress.updateOne(
      { userId: submission.userId, questId: quest._id },
      { $set: { daysDone: 0, lastCheckInDay: null } }
    );
  }
  if (submission.kind === 'party' && submission.partyId) {
    // ห้องกลับเป็น started ให้หัวหน้าถ่ายรูปกลุ่มส่งใหม่
    await Party.updateOne({ _id: submission.partyId, status: 'reviewing' }, { $set: { status: 'started' } });
  }
  await safeNotify(() => notifyQuestRejected(submission.userId, quest, submission._id, checkIn));
  return submission;
};

// ลบรูปของ submission ที่ไม่ผ่าน (คง photoHash/contentType ไว้) — GET /submissions/:id/photo จะตอบ 404
const purgeRejectedPhoto = (submissionId) =>
  QuestSubmission.updateOne({ _id: submissionId, status: 'rejected' }, { $unset: { photoData: 1 } });

// Today Feed (ผู้ใช้ออกแบบ 30 ก.ย. 2026) — ฟีดโชว์แค่ของที่ผ่านการตรวจ "วันนี้" (ตัดวันตาม utils/questDay.js = เที่ยงคืน
// เวลาญี่ปุ่น) ขึ้นวันใหม่ = ลบรูปของที่ตัดสินแล้วตั้งแต่เมื่อวานทิ้ง ให้ Atlas ฟรี (512MB) ไม่เต็มจากรูปหลักฐาน
// - pending: เก็บรูปไว้จนกว่าจะตัดสิน (ผู้ตรวจต้องเห็น) แม้ข้ามวัน — ค้างได้ไม่เกิน 48 ชม. อยู่แล้ว
// - rejected: ลบทันทีตอนตัดสิน (purgeRejectedPhoto) + เก็บกวาดตัวที่หลุดตรงนี้
// - approved: ลบเมื่อ decidedAt ก่อนเที่ยงคืนวันนี้ (ฟีดเลิกโชว์พอดี) — photoHash ยังอยู่ กันเอารูปเดิมมาส่งซ้ำได้เหมือนเดิม
// เรียกจาก sweep แบบ lazy (ไม่มี scheduler) — รูปเมื่อวานอาจค้างถึง request แรกของวันใหม่ แต่ฟีดไม่โชว์แล้ว
const purgeExpiredPhotos = () =>
  QuestSubmission.updateMany(
    {
      photoData: { $exists: true },
      $or: [{ status: 'rejected' }, { status: 'approved', decidedAt: { $lt: startOfToday() } }],
    },
    { $unset: { photoData: 1 } }
  );

// แจ้งเตือนพังไม่ควรทำให้การตัดสิน/ให้รางวัลที่บันทึกไปแล้วพังตาม
const safeNotify = async (fn) => {
  try {
    await fn();
  } catch (err) {
    console.error('สร้างแจ้งเตือนผลตรวจภารกิจไม่สำเร็จ:', err.message);
  }
};

// งานเก็บกวาดเบื้องหลัง (ตอนนี้เหลือแค่ลบรูปหมดอายุ — ค้างเกิน 48 ชม. ไม่ตัดสินอัตโนมัติแล้ว ส่งให้แอดมินแทน)
// ไม่มี scheduler (Render free tier หลับ) เลยเรียกแบบ lazy จาก route ที่คนเปิดบ่อย (GET /quests, /auth/me,
// /reviews/queue, /feed) throttle ไว้นาทีละครั้งทั้ง server ไม่ให้ทุก request ต้อง query เพิ่ม
let lastSweepAt = 0;
const SWEEP_EVERY_MS = 60 * 1000;

const sweepExpiredSubmissions = async ({ force = false } = {}) => {
  const now = Date.now();
  if (!force && now - lastSweepAt < SWEEP_EVERY_MS) return 0;
  lastSweepAt = now;

  const res = await purgeExpiredPhotos();
  return res.modifiedCount || 0;
};

// เรียกจาก route แบบไม่ให้ request หลักพังถ้า sweep มีปัญหา
const sweepQuietly = async () => {
  try {
    await sweepExpiredSubmissions();
  } catch (err) {
    console.error('เก็บกวาดหลักฐาน (ลบรูปหมดอายุ) ไม่สำเร็จ:', err.message);
  }
};

// payload ที่แอพใช้ร่วมกันทุกหน้า (คิวตรวจ, รอตรวจของฉัน, ฟีด) — ไม่มีรูปจริงในนี้ มีแค่ URL
// ⚠️ ต้อง populate('userId', PUBLIC_USER_FIELDS) และ populate('questId', QUEST_FIELDS) มาก่อน
const toSubmissionPayload = (s, viewerId = null) => ({
  id: s._id,
  kind: s.kind,
  status: s.status,
  photoUrl: `/submissions/${s._id}/photo?v=${s.createdAt ? s.createdAt.getTime() : 0}`,
  submittedAt: s.createdAt,
  decidedAt: s.decidedAt,
  approvals: s.approvals.length,
  rejections: s.rejections.length,
  approvalsNeeded: APPROVALS_NEEDED,
  // ค้างเกิน 48 ชม. — รอแอดมินตัดสิน (แอพโชว์ "Waiting for an admin" / ป้ายในคิวของแอดมิน)
  escalated: isEscalated(s),
  checkIn: s.kind === 'check_in' ? s.checkIn : null,
  reward: s.reward || { points: 0, xp: 0 },
  quest: s.questId && s.questId.title
    ? {
        id: s.questId._id,
        title: s.questId.title,
        detail: s.questId.detail,
        category: s.questId.category,
        co2eEstimateKg: s.questId.co2eEstimateKg ?? null,
        durationDays: s.questId.durationDays || 1,
      }
    : null,
  user: s.userId && s.userId.displayName !== undefined ? toPublicUser(s.userId) : null,
  cheers: s.cheers ? s.cheers.length : 0,
  cheeredByMe: Boolean(viewerId && s.cheers && s.cheers.some((id) => String(id) === String(viewerId))),
});

module.exports = {
  APPROVALS_NEEDED,
  REJECTIONS_NEEDED,
  ESCALATE_AFTER_MS,
  escalationCutoff,
  isEscalated,
  photoHashOf,
  isDuplicatePhoto,
  finalizeSubmission,
  sweepExpiredSubmissions,
  sweepQuietly,
  purgeExpiredPhotos,
  toSubmissionPayload,
  PUBLIC_USER_FIELDS,
  QUEST_FIELDS,
};
