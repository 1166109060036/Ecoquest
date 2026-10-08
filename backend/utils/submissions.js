// หลักฐานภารกิจ (รูปถ่าย) — ดู models/QuestSubmission.js
//
// 7 ต.ค. 2026 อาจารย์ติงว่าให้ผู้เล่นตรวจทุกอันเป็นภาระ และถ้าไม่มีใครตรวจ คนทำจะไม่ได้แต้มจนหมดกำลังใจ (เป้าหมายคือ
// สร้างความตระหนัก/การมีส่วนร่วม ไม่ใช่จับโกง) ผู้ใช้เลือก "ได้แต้มทันที + รายงาน":
//   - ส่งรูป = ผ่านทันที ได้แต้ม/XP/CO2 เลย (awardSubmission) — ยังต้องมีรูป + ห้ามใช้รูปเดิมซ้ำเหมือนเดิม
//   - ผู้เล่น (บัญชีจริง) กดรายงานโพสต์ในฟีดได้ / ครบ REPORTS_TO_HIDE คน = ซ่อนไว้ก่อน (routes/feed.js)
//   - แอดมินดูเฉพาะที่ถูกรายงาน: เก็บไว้ / ถอนรูป (แต้มอยู่) / ถอนรูป + ยึดแต้มคืน (revokeSubmission) — routes/reviews.js
// ระบบเดิม (28 ก.ย.–7 ต.ค. 2026: ผู้เล่น 2 คนตรวจ / แอดมินตัดสิน / ค้าง 48 ชม. รอแอดมิน + รางวัลคนตรวจ) เลิกใช้แล้ว
// ของที่ยัง pending ค้างจากระบบเดิม sweep อนุมัติให้หมด (approveLegacyPending)
const crypto = require('crypto');
const QuestSubmission = require('../models/QuestSubmission');
const QuestHistory = require('../models/QuestHistory');
const Quest = require('../models/Quest');
const Party = require('../models/Party');
const User = require('../models/User');
const progression = require('./progression');
const { awardQuest, awardCheckInDay } = require('./questRewards');
const { finalDayBase } = require('./checkInRewards');
const { comboForSubmission } = require('./combo');
const { notifyQuestCompleted, notifyQuestApproved, notifyPartyReward, notifyProofRevoked } = require('./notifications');
const { avatarUrlFor, cosmeticsFor } = require('./avatar');
const { startOfToday } = require('./questDay');
const { purgeExpiredFridgePhotos } = require('./fridgePhotos');

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

// รายงานครบกี่คน (คนละบัญชี) ถึงซ่อนโพสต์จากฟีดไว้ก่อนแอดมินดู — คนเดียวรายงานยังโชว์อยู่ (กันกลั่นแกล้งคนเดียว)
const REPORTS_TO_HIDE = 3;
const REPORT_REASONS = ['not_done', 'personal_info', 'inappropriate', 'other'];

const photoHashOf = (buffer) => crypto.createHash('sha256').update(buffer).digest('hex');

// รูปเดิมของตัวเองส่งซ้ำไม่ได้ทุกสถานะ (กันถ่ายครั้งเดียวใช้ทำเควสซ้ำได้ไม่จำกัด)
const isDuplicatePhoto = async (userId, photoHash) =>
  Boolean(await QuestSubmission.exists({ userId, photoHash }));

// ผู้ใช้ปลายทางที่ได้ผลของ submission นี้ (party = สมาชิกทุกคน, อื่นๆ = คนส่ง)
const recipientsOf = (submission) =>
  submission.kind === 'party' && submission.memberIds.length > 0
    ? submission.memberIds
    : [submission.userId];

// ให้รางวัลของ submission ที่ผ่านแล้ว 1 ครั้ง — ผู้เรียกต้องกันเรียกซ้ำเอง (ส่งใหม่: สร้างเป็น approved แล้วเรียกครั้งเดียว /
// ของเก่า: หลัง CAS pending -> approved) บันทึก awards (ไว้ยึดคืน) + reward ของคนส่งลง submission
// notify:
//   'instant'  = คนส่งเห็นรางวัลจาก response อยู่แล้ว -> แจ้งเตือนแบบ quest_complete (ไม่เด้งฉลองซ้ำ)
//                สมาชิกปาร์ตี้คนอื่นไม่ได้กดเอง -> quest_approved (แอพเด้งเอฟเฟครางวัลให้ตอนเปิด, main_shell.dart)
//   'approved' = ของเก่าที่เพิ่งผ่าน -> quest_approved ทุกคน (แบบเดิม)
// คืน { owner: ผลของคนส่ง (ผลจาก awardQuest/awardCheckInDay) หรือ null, combo }
const awardSubmission = async (submission, quest, { notify = 'instant' } = {}) => {
  const checkIn = submission.kind === 'check_in' ? submission.checkIn : null;
  const ownerId = String(submission.userId);
  const awards = [];
  let owner = null;
  let combo = null;

  if (checkIn && !checkIn.finished) {
    // เช็คอินวันระหว่างทาง — แต้มรายวัน (utils/checkInRewards.js) + แถว checkIn ที่นับ CO2 ของวันนั้น
    // ยังไม่นับเป็นทำเควสสำเร็จ (เหรียญ/Bingo/ยอดรวมนับตอนจบ) — utils/questRewards.js#awardCheckInDay
    owner = await awardCheckInDay(submission.userId, quest, { completedAt: submission.createdAt });
    if (owner) {
      awards.push({
        userId: submission.userId,
        historyId: owner.history._id,
        points: owner.reward.points,
        xp: owner.reward.xp,
        checkInDay: true,
      });
    }
  } else {
    // Daily Variety Combo เฉพาะเควส solo ธรรมดา (ไม่ใช่ปาร์ตี้ / วันสุดท้ายของเควสหลายวัน)
    combo = submission.kind === 'quest' ? await comboForSubmission(submission) : null;
    const comboMultiplier = combo ? combo.multiplier : 1;
    // วันสุดท้ายของเควสหลายวัน = รายวัน + โบนัสจบเควส (utils/checkInRewards.js) แทนแต้มเควสเฉยๆ
    const base = checkIn && checkIn.finished ? finalDayBase(quest) : null;
    for (const userId of recipientsOf(submission)) {
      const result = await awardQuest(userId, quest, { completedAt: submission.createdAt, comboMultiplier, base });
      if (!result) continue; // user ถูกลบไปแล้ว
      awards.push({
        userId,
        historyId: result.history._id,
        points: result.reward.points,
        xp: result.reward.xp,
        checkInDay: false,
      });
      const isOwner = String(userId) === ownerId;
      if (isOwner) owner = result;
      if (notify === 'approved') {
        await safeNotify(() => notifyQuestApproved(userId, quest, submission._id, result.reward, checkIn));
      } else if (!isOwner) {
        await safeNotify(() => notifyPartyReward(userId, quest, submission._id, result.reward));
      }
    }
  }

  const reward = owner
    ? { points: owner.reward.points, xp: owner.reward.xp, comboMultiplier: combo ? combo.multiplier : 1 }
    : { points: 0, xp: 0 };
  await QuestSubmission.updateOne({ _id: submission._id }, { $set: { reward, awards } });
  submission.reward = reward;
  submission.awards = awards;

  if (owner && notify === 'instant') {
    await safeNotify(() => notifyQuestCompleted(submission.userId, quest, owner.history._id, owner.reward.points));
  } else if (owner && notify === 'approved' && checkIn && !checkIn.finished) {
    await safeNotify(() => notifyQuestApproved(submission.userId, quest, submission._id, reward, checkIn));
  }

  if (submission.kind === 'party' && submission.partyId) {
    await Party.updateOne(
      { _id: submission.partyId, status: { $in: ['started', 'reviewing'] } },
      { $set: { status: 'completed', completedAt: new Date() } }
    );
  }
  return { owner, combo };
};

// ของที่ยัง pending จากระบบให้คนตรวจเดิม — อนุมัติทีละอันแบบ compare-and-swap (pending -> approved) กันให้รางวัลซ้ำ
// ถ้า sweep 2 request ทับกัน / แจ้งเตือน quest_approved ให้คนที่รอมานานได้เด้งฉลองรางวัล
const approveLegacyPending = async () => {
  const stale = await QuestSubmission.find({ status: 'pending' }).select('_id').limit(50);
  let count = 0;
  for (const { _id } of stale) {
    const submission = await QuestSubmission.findOneAndUpdate(
      { _id, status: 'pending' },
      { $set: { status: 'approved', decidedBy: 'auto', decidedAt: new Date() } },
      { new: true, projection: { photoData: 0 } }
    );
    if (!submission) continue;
    // อ่าน template แม้เควสถูกปิดไปแล้วก็ยังให้รางวัล (ทำไปแล้วจริงก่อนปิด) — ถูกลบทิ้งจริงเท่านั้นถึงข้าม
    const quest = await Quest.findById(submission.questId);
    if (quest) await awardSubmission(submission, quest, { notify: 'approved' });
    count += 1;
  }
  return count;
};

// แอดมินตัดสินว่ารูปไม่ได้แสดงว่าทำเควสจริง — ยึดแต้ม/XP คืนจากทุกคนที่ได้ (ลบแถว QuestHistory = CO2 กับประวัติ
// หายไปด้วย) ถอนรูปออกจากฟีด เปลี่ยนเป็น rejected (คอมโบไม่นับแล้ว) + แจ้งเตือนเจ้าของ
// ไม่ถอนเหรียญที่ปลดล็อกไปแล้ว / โบนัส Bingo / streak (ซับซ้อนเกินไปและได้ไม่คุ้ม — บันทึกเป็นข้อจำกัด)
// ⚠️ ผู้เรียกต้องล็อกสถานะก่อน (reportStatus open -> revoked แบบ CAS) ไม่งั้นกดซ้อนกันจะยึดซ้ำ
const revokeSubmission = async (submission, adminId) => {
  for (const award of submission.awards || []) {
    const removed = await QuestHistory.deleteOne({ _id: award.historyId });
    if (removed.deletedCount === 0) continue; // แถวถูกลบไปแล้ว (เช่น Super Energy) — ไม่ยึดซ้ำ
    const dec = award.checkInDay ? 0 : 1;
    // ไม่ให้ติดลบ (อาจใช้แต้มไปแล้ว — ร้านปิดอยู่แต่กันไว้)
    await User.updateOne({ _id: award.userId }, [
      {
        $set: {
          points: { $max: [0, { $subtract: [{ $ifNull: ['$points', 0] }, award.points || 0] }] },
          xp: { $max: [0, { $subtract: [{ $ifNull: ['$xp', 0] }, award.xp || 0] }] },
          totalQuestsCompleted: {
            $max: [0, { $subtract: [{ $ifNull: ['$totalQuestsCompleted', 0] }, dec] }],
          },
        },
      },
    ]);
    // level เป็น cache ของ xp
    const user = await User.findById(award.userId).select('xp');
    if (user) await User.updateOne({ _id: user._id }, { $set: { level: progression.levelFromXp(user.xp) } });
  }

  const now = new Date();
  await QuestSubmission.updateOne(
    { _id: submission._id },
    {
      $set: {
        status: 'rejected',
        decidedBy: 'admin',
        decidedAt: now,
        removedFromFeed: true,
        removedAt: now,
        removedBy: adminId,
        hiddenByReports: false,
      },
      $unset: { photoData: 1 },
    }
  );
  const quest = await Quest.findById(submission.questId).select('title');
  const lost = (submission.awards || []).find((a) => String(a.userId) === String(submission.userId));
  await safeNotify(() => notifyProofRevoked(submission.userId, quest, submission._id, lost ? lost.points : 0));
};

// Today Feed (ผู้ใช้ออกแบบ 30 ก.ย. 2026) — ฟีดโชว์แค่ของที่ผ่านการตรวจ "วันนี้" (ตัดวันตาม utils/questDay.js = เที่ยงคืน
// เวลาญี่ปุ่น) ขึ้นวันใหม่ = ลบรูปของที่ตัดสินแล้วตั้งแต่เมื่อวานทิ้ง ให้ Atlas ฟรี (512MB) ไม่เต็มจากรูปหลักฐาน
// - rejected (แอดมินยึดแต้มคืน): ลบทันทีตอนตัดสิน (revokeSubmission) + เก็บกวาดตัวที่หลุดตรงนี้
// - approved: ลบเมื่อ decidedAt ก่อนเที่ยงคืนวันนี้ (ฟีดเลิกโชว์พอดี) ยกเว้นถูกรายงานรอแอดมินดู
//   — photoHash ยังอยู่ กันเอารูปเดิมมาส่งซ้ำได้เหมือนเดิม
// เรียกจาก sweep แบบ lazy (ไม่มี scheduler) — รูปเมื่อวานอาจค้างถึง request แรกของวันใหม่ แต่ฟีดไม่โชว์แล้ว
const purgeExpiredPhotos = () =>
  QuestSubmission.updateMany(
    {
      photoData: { $exists: true },
      $or: [
        { status: 'rejected' },
        // ถูกรายงานรอแอดมินดู = เก็บรูปไว้ก่อน (แอดมินต้องเห็น) ข้ามวันได้
        { status: 'approved', decidedAt: { $lt: startOfToday() }, reportStatus: { $ne: 'open' } },
      ],
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

// งานเก็บกวาดเบื้องหลัง (อนุมัติของ pending ค้างจากระบบเดิม + ลบรูปหลักฐานหมดอายุ + รูปของในตู้เย็นที่หมดอายุ)
// ไม่มี scheduler (Render free tier หลับ) เลยเรียกแบบ lazy จาก route ที่คนเปิดบ่อย (GET /quests, /auth/me,
// /reviews/queue, /feed) throttle ไว้นาทีละครั้งทั้ง server ไม่ให้ทุก request ต้อง query เพิ่ม
let lastSweepAt = 0;
const SWEEP_EVERY_MS = 60 * 1000;

const sweepExpiredSubmissions = async ({ force = false } = {}) => {
  const now = Date.now();
  if (!force && now - lastSweepAt < SWEEP_EVERY_MS) return 0;
  lastSweepAt = now;

  const approved = await approveLegacyPending();
  const res = await purgeExpiredPhotos();
  // รูปของในตู้เย็นที่หมดอายุแล้ว (ของคนที่ไม่ได้เปิดหน้า Fridge ด้วย) — utils/fridgePhotos.js
  const fridge = await purgeExpiredFridgePhotos();
  return approved + (res.modifiedCount || 0) + (fridge.modifiedCount || 0);
};

// เรียกจาก route แบบไม่ให้ request หลักพังถ้า sweep มีปัญหา
const sweepQuietly = async () => {
  try {
    await sweepExpiredSubmissions();
  } catch (err) {
    console.error('เก็บกวาดหลักฐาน (อนุมัติของค้าง/ลบรูปหมดอายุ) ไม่สำเร็จ:', err.message);
  }
};

// payload ที่แอพใช้ร่วมกันทุกหน้า (โพสต์ที่ถูกรายงาน, ของฉัน, ฟีด) — ไม่มีรูปจริงในนี้ มีแค่ URL
// ⚠️ ต้อง populate('userId', PUBLIC_USER_FIELDS) และ populate('questId', QUEST_FIELDS) มาก่อน
const toSubmissionPayload = (s, viewerId = null) => ({
  id: s._id,
  kind: s.kind,
  status: s.status,
  photoUrl: `/submissions/${s._id}/photo?v=${s.createdAt ? s.createdAt.getTime() : 0}`,
  submittedAt: s.createdAt,
  decidedAt: s.decidedAt,
  checkIn: s.kind === 'check_in' ? s.checkIn : null,
  // ข้อมูลจากฟอร์มของเควส (utils/proofForm.js) — โชว์ในฟีด/แอดมินใช้ประกอบการดูรูป
  details: s.details && (s.details.choices || s.details.count || s.details.place) ? s.details : null,
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
  reportedByMe: Boolean(viewerId && s.reports && s.reports.some((r) => String(r.userId) === String(viewerId))),
});

module.exports = {
  REPORTS_TO_HIDE,
  REPORT_REASONS,
  photoHashOf,
  isDuplicatePhoto,
  awardSubmission,
  approveLegacyPending,
  revokeSubmission,
  sweepExpiredSubmissions,
  sweepQuietly,
  purgeExpiredPhotos,
  toSubmissionPayload,
  PUBLIC_USER_FIELDS,
  QUEST_FIELDS,
};
