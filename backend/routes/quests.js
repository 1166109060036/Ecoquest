const express = require('express');
const mongoose = require('mongoose');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const QuestProgress = require('../models/QuestProgress');
const FridgeItem = require('../models/FridgeItem');
const Party = require('../models/Party');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const QuestSubmission = require('../models/QuestSubmission');
const { notifyQuestCompleted } = require('../utils/notifications');
const { getUserBonuses, applyBonuses, BASE_VISIBLE_QUESTS } = require('../utils/upgrades');
const { withEnergyBoosts } = require('../utils/inventory');
const { startOfToday, todayKey, yesterdayKey } = require('../utils/questDay');
const { awardQuest, applyStreakNow } = require('../utils/questRewards');
const { decodeImageBase64 } = require('../utils/imageUpload');
const { photoHashOf, isDuplicatePhoto, sweepQuietly, awardSubmission } = require('../utils/submissions');
const { selectVisibleQuests } = require('../utils/questSelection');
const { shopEnabled } = require('../utils/featureFlags');
const { comboForNow, comboSummaryToday, nextNewMultiplier } = require('../utils/combo');
const { checkInRewardInfo } = require('../utils/checkInRewards');
const { validateProofDetails } = require('../utils/proofForm');
const progression = require('../utils/progression');

// เควสที่นับ Daily Variety Combo (utils/combo.js): solo ที่จบในครั้งเดียว — party/เควสหลายวันไม่มีคอมโบ
const hasCombo = (quest) => quest.type === 'solo' && (quest.durationDays || 1) <= 1;

const router = express.Router();

// แปลง quest template + bonus ของ user เป็น payload ที่ส่งให้แอพ — ใช้ร่วมกันทั้ง GET / และ
// GET /progress เพื่อให้ scorePoints/xpReward ที่โชว์ผ่าน applyBonuses ตรงกันเป๊ะทั้ง 2 หน้า
const toQuestPayload = (
  quest,
  bonuses,
  { timesToday, pendingReview, inProgress, startedAt, openPartyCount, daysDone, checkedInToday } = {}
) => {
  const reward = applyBonuses(bonuses, quest);
  return {
    id: quest._id,
    title: quest.title,
    description: quest.description,
    detail: quest.detail,
    imageKey: quest.imageKey,
    category: quest.category,
    type: quest.type,
    difficulty: quest.difficulty,
    impact: quest.impact,
    scorePoints: reward.points,
    xpReward: reward.xp,
    co2eEstimateKg: quest.co2eEstimateKg ?? null,
    impactCategory: quest.impactCategory,
    impactMetric: quest.impactMetric,
    isDaily: quest.isDaily,
    actionKey: quest.actionKey,
    randomPool: quest.randomPool,
    // เควสทำซ้ำได้ไม่จำกัดต่อวันแล้ว (28 ก.ย. 2026) — completedToday เป็น false เสมอ คงไว้ให้แอพเวอร์ชันเก่าที่ยัง
    // เช็คฟิลด์นี้ไม่ล็อกปุ่ม / timesToday = วันนี้ทำเควสนี้สำเร็จไปแล้วกี่ครั้ง (ไม่นับแถวเช็คอินระหว่างทาง)
    completedToday: false,
    timesToday: timesToday || 0,
    // หลักฐานของเควสนี้ที่ส่งไปแล้วยังรอตรวจอยู่กี่ครั้ง (ระบบตรวจสอบภารกิจ — utils/submissions.js)
    pendingReview: pendingReview || 0,
    // ต้องถ่ายรูปหลักฐานตอน Complete ไหม (ทุก solo ยกเว้น Check Food ที่ระบบตรวจจากตู้เย็นเอง)
    requiresProof: quest.type === 'party' || quest.actionKey !== 'fridge_check',
    // ช่องกรอกเพิ่มในแผ่นถ่ายรูป (utils/proofForm.js) — null = ส่งแค่รูป
    proofForm: quest.proofForm || null,
    // เควสที่ user กด Start ไว้แต่ยังไม่ Complete — ดู models/QuestProgress.js
    inProgress: Boolean(inProgress),
    startedAt: startedAt || null,
    // ---- เควสหลายวัน (Food Saver 3/7) — daysDone/checkedInToday มีค่าจริงเฉพาะใน GET /progress ----
    durationDays: quest.durationDays || 1,
    daysDone: daysDone || 0,
    checkedInToday: Boolean(checkedInToday),
    // รางวัลเควสหลายวัน (6 ต.ค. 2026): ได้ทุกวันที่เช็คอินผ่าน + โบนัสจบเควส — null = เควสวันเดียว (utils/checkInRewards.js)
    // scorePoints/xpReward ด้านบนยังเป็นค่าเดิมของเควส (แอพเวอร์ชันเก่าโชว์ค่านั้น) แอพใหม่โชว์ total แทน
    checkInReward: checkInRewardInfo(quest, applyBonuses, bonuses),
    // ---- เฉพาะ party quest ----
    // location/capacity ตรงนี้เป็นแค่ค่า default ให้ฟอร์มสร้างห้องดึงไปเติม
    // (ห้องจริงแต่ละห้องนัดคนละเวลา/สถานที่กันได้ ดูรายละเอียดที่ Party model)
    location: quest.location,
    capacity: quest.capacity,
    minLevelToHost: quest.minLevelToHost,
    openPartyCount: openPartyCount || 0,
  };
};

// @route   GET /api/quests
// @desc    ลิสต์ quest ที่เปิดใช้งานอยู่ + บอกด้วยว่า quest รายวันอันไหนวันนี้ทำไปแล้ว/กำลังทำอยู่
router.get('/', authMiddleware, async (req, res) => {
  try {
    // ตัดสินหลักฐานที่ค้างเกิน 48 ชม. (lazy — ไม่มี scheduler) ก่อนนับ pendingReview ด้านล่าง
    await sweepQuietly();
    const allQuests = await Quest.find({ isActive: true }).sort({ sortOrder: 1, createdAt: 1 });

    // ดึงมาแค่ 3 ฟิลด์ boost expiry ก็พอ ไม่ใช่ user ทั้งก้อน (กัน avatarData Buffer ด้วยในตัว
    // เพราะไม่ได้ select มันมา) — ใส่ withEnergyBoosts ตรงนี้เพื่อให้การ์ดเควสโชว์ตัวเลขหลังคูณบัฟ
    // Energy ที่ยังไม่หมดอายุด้วย ไม่งั้นการ์ดโชว์ตัวเลขนึง แต่กดทำจริงได้อีกตัวเลข ดูเหมือนบั๊ก
    const boostUser = await User.findById(req.userId).select(
      'redEnergyExpiresAt blueEnergyExpiresAt greenEnergyExpiresAt'
    );
    const bonuses = withEnergyBoosts(await getUserBonuses(req.userId), boostUser);
    // upgrade "Quest Unlock" เพิ่มจำนวน solo quest ที่เห็นได้ — วิธีสุ่ม/ปักหมุดดู utils/questSelection.js
    // ร้านปิด (utils/featureFlags.js) = ซื้อ Quest Unlock ไม่ได้แล้ว -> เห็นเควส solo ครบทุกอัน
    const soloLimit = shopEnabled() ? BASE_VISIBLE_QUESTS + bonuses.questSlots : Infinity;
    const visibleQuests = selectVisibleQuests(allQuests, req.userId, soloLimit);

    // ดึงประวัติของวันนี้ + เควสที่กำลัง Start ค้างอยู่มาทีเดียว แล้วค่อย map (ไม่ query ทีละ quest)
    const [todayHistory, progressRows, pendingRows, combo] = await Promise.all([
      QuestHistory.find({
        userId: req.userId,
        completedAt: { $gte: startOfToday() },
        checkIn: { $ne: true },
      }).select('questId'),
      QuestProgress.find({ userId: req.userId }).select('questId'),
      QuestSubmission.aggregate([
        { $match: { userId: new mongoose.Types.ObjectId(String(req.userId)), status: 'pending' } },
        { $group: { _id: '$questId', count: { $sum: 1 } } },
      ]),
      comboSummaryToday(req.userId),
    ]);
    const pendingByQuest = new Map(pendingRows.map((r) => [String(r._id), r.count]));

    const timesToday = new Map();
    for (const h of todayHistory) {
      const id = h.questId.toString();
      timesToday.set(id, (timesToday.get(id) || 0) + 1);
    }
    const inProgressIds = new Set(progressRows.map((p) => p.questId.toString()));

    // party quest ตอนนี้ไม่มี "เข้าร่วม/ยังไม่เข้าร่วม" ต่อ quest แล้ว — เปลี่ยนเป็นสร้าง/เข้าร่วม
    // "ห้อง" (Party) แทน เลยแค่บอกว่ามีกี่ห้องที่ยังเปิดรับอยู่ (openPartyCount) ให้การ์ดโชว์เฉยๆ
    // ยิงทีเดียวสำหรับทุก party quest ไม่ query ทีละอัน
    const partyQuestIds = visibleQuests.filter((q) => q.type === 'party').map((q) => q._id);
    const openPartyCounts = new Map();

    if (partyQuestIds.length > 0) {
      const counts = await Party.aggregate([
        { $match: { questId: { $in: partyQuestIds }, status: 'open' } },
        { $group: { _id: '$questId', count: { $sum: 1 } } },
      ]);
      for (const c of counts) openPartyCounts.set(c._id.toString(), c.count);
    }

    res.json({
      quests: visibleQuests.map((q) => {
        const id = q._id.toString();
        return {
          ...toQuestPayload(q, bonuses, {
            timesToday: timesToday.get(id) || 0,
            pendingReview: pendingByQuest.get(id) || 0,
            inProgress: inProgressIds.has(id),
            openPartyCount: openPartyCounts.get(id) || 0,
          }),
          // ตัวคูณที่จะได้ถ้าทำเควสนี้ตอนนี้ (null = เควสนี้ไม่มีคอมโบ) — ยังไม่ได้คิดอันที่อาจไม่ผ่านการตรวจ
          comboMultiplier: hasCombo(q) ? combo.previewFor(id) : null,
        };
      }),
      // Daily Variety Combo วันนี้ — แอพโชว์ "3 different quests today · next new quest ×1.3"
      combo: {
        distinctToday: combo.distinctToday,
        nextNewMultiplier: combo.nextNewMultiplier,
        maxMultiplier: combo.maxMultiplier,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/quests/history
// @desc    ประวัติ quest ที่ทำสำเร็จของ user คนนี้ (ล่าสุดขึ้นก่อน)
// ต้องประกาศไว้ก่อน route ที่มี :id เพื่อไม่ให้ 'history' ถูกจับเป็น id
router.get('/history', authMiddleware, async (req, res) => {
  try {
    // กัน client ขอทีเดียวเยอะเกินไป
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);

    // แถวเช็คอินระหว่างทางของเควสหลายวันไม่ใช่ "ทำเควสสำเร็จ" — โชว์แค่แถวที่จบเควสจริง
    const history = await QuestHistory.find({ userId: req.userId, checkIn: { $ne: true } })
      .sort({ completedAt: -1 })
      .limit(limit)
      // ดึงเฉพาะฟิลด์ที่ต้องใช้โชว์ ไม่ต้องลาก quest มาทั้งก้อน
      .populate('questId', 'title category type');

    res.json({
      history: history.map((h) => ({
        id: h._id,
        // quest ถูกลบทิ้งไปแล้วก็ยังต้องโชว์ประวัติได้ ไม่ให้พัง
        questTitle: h.questId ? h.questId.title : 'Unknown quest',
        category: h.questId ? h.questId.category : null,
        pointsEarned: h.pointsEarned,
        xpEarned: h.xpEarned,
        completedAt: h.completedAt,
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/quests/progress
// @desc    เควสที่กด Start ไว้แล้วแต่ยังไม่กด Complete (หน้า Progress) — ค้างได้ไม่จำกัดวัน
// ต้องประกาศไว้ก่อน route ที่มี :id เหมือน /history
router.get('/progress', authMiddleware, async (req, res) => {
  try {
    const progressRows = await QuestProgress.find({ userId: req.userId })
      .sort({ startedAt: -1 })
      .populate('questId');

    // quest ถูกลบ/ปิดใช้งานไปหลังจาก start แล้ว — ตัดออก ไม่ให้การ์ดพัง (แถวนี้จะค้างเป็น
    // orphan ไปเรื่อยๆ ก็ไม่มีผลอะไรเพราะไม่โผล่ให้เห็นและ complete ก็ทำไม่ได้อยู่ดีเพราะ quest หาไม่เจอ)
    const activeRows = progressRows.filter((p) => p.questId && p.questId.isActive);

    const boostUser = await User.findById(req.userId).select(
      'redEnergyExpiresAt blueEnergyExpiresAt greenEnergyExpiresAt'
    );
    const bonuses = withEnergyBoosts(await getUserBonuses(req.userId), boostUser);
    const today = todayKey();
    const yesterday = yesterdayKey();

    res.json({
      // ⚠️ จงใจไม่ใช้ selectVisibleQuests (สุ่มรายวัน + จำกัดจำนวน) แบบ GET / —
      // เควสที่ start ไปแล้วต้องโผล่ในหน้านี้เสมอ ไม่ว่าจะโดนสุ่มไม่ติดหรือโดนลิมิตตัดในวันถัดไป
      // ไม่งั้นผู้ใช้จะค้างเควสที่ทำต่อไม่ได้เลย (เควสหลายวันต้องกลับมาเช็คอินที่นี่ทุกวัน)
      progress: activeRows.map((p) =>
        toQuestPayload(p.questId, bonuses, {
          inProgress: true,
          startedAt: p.startedAt,
          // เช็คอินล่าสุดไม่ใช่วันนี้/เมื่อวาน = ลืมไปแล้ว เช็คอินครั้งถัดไปจะนับใหม่เป็นวันที่ 1 — โชว์ 0 เลย
          // ไม่โชว์ตัวเลขเดิมที่กำลังจะหายให้ผู้เล่นเข้าใจผิด
          daysDone: [today, yesterday].includes(p.lastCheckInDay) ? p.daysDone : 0,
          checkedInToday: p.lastCheckInDay === today,
        })
      ),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/quests/:id/start
// @desc    กด Start เควส — บันทึกว่ากำลังทำอยู่ ยังไม่ได้คะแนน ต้องไปกด Complete ที่หน้า Progress อีกที
router.post('/:id/start', authMiddleware, async (req, res) => {
  try {
    const quest = await Quest.findById(req.params.id);
    if (!quest || !quest.isActive) {
      return res.status(404).json({ message: 'Quest not found' });
    }

    // party quest เริ่ม/จบผ่านห้อง (Party) ที่แท็บ Community เท่านั้น ไม่มี Start รายคนตรงนี้
    if (quest.type === 'party') {
      return res.status(400).json({
        message: 'Party quests are started from the Party tab',
      });
    }

    // ⚠️ ไม่มี gate "วันละครั้ง" แล้ว (28 ก.ย. 2026 ผู้ใช้สั่ง) — ทำเควสเดิมซ้ำได้ไม่จำกัดต่อวัน
    // (Quest.isDaily ยังอยู่ใน model แต่ไม่ถูกใช้บังคับแล้ว) CO2 ต่อเควสนับวันละครั้งที่ utils/profilePayload.js

    // upsert แบบกันแข่ง — กด Start ซ้ำเควสเดิม (หรือกดรัวๆพร้อมกันจากหลาย request) ไม่พัง
    // ได้แถวเดิมกลับไปเฉยๆ ไม่ได้สร้างซ้ำ (unique index กันไว้อีกชั้น เผื่อ race จริง)
    let progress;
    try {
      progress = await QuestProgress.findOneAndUpdate(
        { userId: req.userId, questId: quest._id },
        { $setOnInsert: { startedAt: new Date() } },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
    } catch (err) {
      if (err.code === 11000) {
        progress = await QuestProgress.findOne({ userId: req.userId, questId: quest._id });
      } else {
        throw err;
      }
    }

    res.json({
      message: 'Quest started',
      progress: {
        id: progress._id,
        questId: progress.questId,
        startedAt: progress.startedAt,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE /api/quests/:id/start
// @desc    ยกเลิกเควสที่กด Start ไว้ (เอาออกจากหน้า Progress โดยไม่ได้คะแนน)
router.delete('/:id/start', authMiddleware, async (req, res) => {
  try {
    const removed = await QuestProgress.findOneAndDelete({
      userId: req.userId,
      questId: req.params.id,
    });
    if (!removed) {
      return res.status(404).json({ message: 'Quest is not in progress' });
    }
    res.json({ message: 'Quest cancelled' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/quests/:id/complete
// @desc    ทำ quest สำเร็จ — 2 แบบ (ดู utils/submissions.js) ทั้งสองแบบได้รางวัลทันที ตอบ status: 'completed'
//          - เควสที่ต้องมีหลักฐาน (solo ทุกอันยกเว้น Check Food): body ต้องมี photoBase64/photoContentType
//            -> สร้าง QuestSubmission ที่ผ่านทันที (7 ต.ค. 2026 เลิกให้คนตรวจ — อาจารย์ห่วงภาระคนตรวจ/คนทำหมดกำลังใจ)
//               ขึ้นฟีด ผู้เล่นคนอื่นรายงานได้ถ้าดูไม่ได้ทำจริง
//          - Check Food: ระบบตรวจจากของในตู้เย็นเอง (ไม่มีรูป)
//          body: { photoBase64?, photoContentType? }
// แอพย่อเหลือด้านยาวสุด 960px quality 70 (~100-200KB, lib/widgets/proof_capture_sheet.dart) — 2MB เผื่อ PNG/แอพรุ่นเก่า
const MAX_PROOF_PHOTO_BYTES = 2 * 1024 * 1024;

router.post('/:id/complete', authMiddleware, async (req, res) => {
  try {
    const quest = await Quest.findById(req.params.id);
    if (!quest || !quest.isActive) {
      return res.status(404).json({ message: 'Quest not found' });
    }

    // party quest เปลี่ยนวิธีทำสำเร็จแล้ว — ต้องผ่านห้อง (Party) และให้หัวหน้าห้องเป็นคนกด
    // ทุกคนในห้องถึงจะได้คะแนนพร้อมกัน ไม่ใช่กดยืนยันเองตรงนี้แบบเดิม
    if (quest.type === 'party') {
      return res.status(400).json({
        message: 'Party quests are completed by the party leader from the Party tab',
      });
    }

    // ---- รูปหลักฐาน ---- ตรวจก่อนเงื่อนไขอื่นทั้งหมด จะได้ไม่ไปแตะ QuestProgress ถ้ารูปใช้ไม่ได้
    const needsProof = quest.actionKey !== 'fridge_check';
    let photo = null;
    if (needsProof) {
      if (!req.body || !req.body.photoBase64) {
        return res.status(400).json({ message: 'Take a photo as proof to complete this quest' });
      }
      try {
        const data = decodeImageBase64(req.body.photoBase64, req.body.photoContentType, MAX_PROOF_PHOTO_BYTES);
        photo = { data, contentType: req.body.photoContentType, hash: photoHashOf(data) };
      } catch (err) {
        return res.status(err.status || 400).json({
          message: err.message === 'Image is too large' ? 'Photo is too large' : 'Invalid photo data',
        });
      }
      if (await isDuplicatePhoto(req.userId, photo.hash)) {
        return res.status(409).json({ message: 'This photo was already used — take a new photo' });
      }
    }

    // ข้อมูลเพิ่มตามฟอร์มของเควส (ส่งคืนอะไร / กี่ชิ้น / ร้านไหน) — ตรวจก่อนแตะ QuestProgress เหมือนรูป
    const proof = validateProofDetails(quest.proofForm, req.body && req.body.proofDetails);
    if (proof.error) {
      return res.status(400).json({ message: proof.error });
    }
    req.proofDetails = proof.details;

    // เควสหลายวัน (Food Saver 3/7) — กด Complete = เช็คอินวันละครั้ง (ธรรมชาติของเควส ไม่ใช่ gate รายวันของระบบ)
    // เช็คจาก lastCheckInDay ใน QuestProgress (Super Energy ลบแค่ QuestHistory ไม่ลบอันนี้)
    const durationDays = quest.durationDays || 1;
    let progressRow = null;
    if (durationDays > 1) {
      progressRow = await QuestProgress.findOne({ userId: req.userId, questId: quest._id });
      if (!progressRow) {
        return res.status(409).json({ message: 'Start this quest first' });
      }
      if (progressRow.lastCheckInDay === todayKey()) {
        return res.status(409).json({ message: 'Already checked in today — come back tomorrow' });
      }
    }

    // ⚠️ ไม่มี gate "วันละครั้ง" แล้ว (28 ก.ย. 2026) — ทำเควสเดิมซ้ำได้ไม่จำกัดต่อวัน

    // quest ที่ต้องทำ action จริงในแอพ — ต้องเช็คว่าทำจริงแล้วก่อนให้คะแนน
    // ไม่งั้นแค่กดปุ่ม Start ก็ได้คะแนนเลย ซึ่งไม่ตรงกับดีไซน์ของ Mini Quest
    // เควสทำซ้ำได้ไม่จำกัดแล้ว — ต้องมีของที่บันทึก "หลังจบเควสนี้ครั้งล่าสุด" (และเป็นของวันนี้) ทุกครั้ง
    // ไม่งั้นบันทึกของครั้งเดียวแล้วกด Complete ได้ไม่รู้จบ
    if (quest.actionKey === 'fridge_check') {
      const lastDone = await QuestHistory.findOne({ userId: req.userId, questId: quest._id })
        .sort({ completedAt: -1 })
        .select('completedAt');
      const since = new Date(Math.max(startOfToday().getTime(), lastDone ? lastDone.completedAt.getTime() : 0));
      const savedToday = await FridgeItem.findOne({
        userId: req.userId,
        addedAt: { $gt: since },
      });
      if (!savedToday) {
        return res.status(400).json({
          message: 'Save your fridge items first to complete this quest',
        });
      }
    }

    // ---- เช็คอินเควสหลายวัน ----
    // เช็คอินติดจากเมื่อวาน = วันถัดไป, ไม่ติด (ลืมไป หรือเช็คอินครั้งแรก) = เริ่มนับวันที่ 1 ใหม่ (ผู้ใช้ตัดสินใจ
    // ให้เหมือน Daily Streak) — ได้แต้มรายวัน + แถว CO2 ของวันนั้นทันทีตอนส่งรูป
    let checkIn = null;
    if (durationDays > 1) {
      const continuing = progressRow.lastCheckInDay === yesterdayKey();
      const daysDone = continuing ? progressRow.daysDone + 1 : 1;
      checkIn = {
        daysDone,
        durationDays,
        restarted: progressRow.daysDone > 0 && !continuing,
        finished: daysDone >= durationDays,
      };

      if (!checkIn.finished) {
        // อัปเดตแบบมีเงื่อนไข lastCheckInDay เดิม — กดรัวๆ พร้อมกันจะผ่านได้แค่ request เดียว
        const updated = await QuestProgress.findOneAndUpdate(
          { _id: progressRow._id, lastCheckInDay: progressRow.lastCheckInDay },
          { $set: { daysDone, lastCheckInDay: todayKey() } },
          { new: true }
        );
        if (!updated) {
          return res.status(409).json({ message: 'Already checked in today — come back tomorrow' });
        }
        return submitProof(req, res, quest, photo, 'check_in', checkIn);
      }
    }

    // ต้องกด Start ไว้ก่อนแล้วเท่านั้นถึง Complete ได้ — findOneAndDelete เป็น atomic ในตัว
    // ถ้ากด Complete รัวๆพร้อมกันหลาย request มีแค่อันเดียวที่ชิงแถวไปได้ อีกอันได้ 409 กันแจก
    // รางวัลซ้ำโดยไม่ต้องมี lock เพิ่ม (หลักการเดียวกับ compare-and-swap ของ Party)
    const claimed = await QuestProgress.findOneAndDelete({
      userId: req.userId,
      questId: quest._id,
    });
    if (!claimed) {
      return res.status(409).json({ message: 'Start this quest first' });
    }

    if (needsProof) {
      return submitProof(req, res, quest, photo, checkIn ? 'check_in' : 'quest', checkIn);
    }

    // ---- ระบบตรวจเองได้ (Check Food) -> รางวัลทันที ----
    const combo = hasCombo(quest) ? await comboForNow(req.userId, quest._id) : null;
    const result = await awardQuest(req.userId, quest, {
      applyStreak: true,
      comboMultiplier: combo ? combo.multiplier : 1,
    });
    if (!result) {
      return res.status(404).json({ message: 'User not found' });
    }
    const { user, reward, history, newAchievements, streakMilestone, bingo } = result;

    // แจ้งเตือนว่าทำเควสสำเร็จ — ไม่ทำให้ทั้ง request พังถ้าสร้างแจ้งเตือนไม่สำเร็จ
    try {
      await notifyQuestCompleted(user._id, quest, history._id, reward.points);
    } catch (notifyErr) {
      console.error('สร้างแจ้งเตือนทำเควสสำเร็จไม่สำเร็จ:', notifyErr.message);
    }

    res.json({
      message: 'Quest completed',
      status: 'completed',
      earned: {
        points: reward.points,
        xp: reward.xp,
      },
      // เหรียญที่เพิ่งปลดล็อกรอบนี้ (ปกติเป็น array ว่าง) — แอพเอาไปเด้งแจ้งเตือน
      newAchievements,
      // ไม่ null เฉพาะตอนวันนี้ตรง milestone ของ Daily Streak (7/14/21/30) — แอพเอาไปเด้ง celebrate
      streakMilestone,
      checkIn,
      combo: combo && { ...combo, nextNewMultiplier: nextNewMultiplier(combo.distinctToday) },
      // Eco Bingo — ครบแถว/การ์ดจากเควสนี้ (null = ไม่มี) แต้มโบนัสบวกเข้า user แยกแล้ว
      bingo,
      user: {
        level: user.level,
        xp: user.xp + (bingo ? bingo.xp : 0),
        points: user.points + (bingo ? bingo.points : 0),
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// บันทึกหลักฐาน (ผ่านทันที) + นับ Daily Streak + ให้รางวัล แล้วตอบรูปแบบเดียวกับ Check Food (status: 'completed')
// แอพเลยเด้งรางวัลได้ทันทีด้วยโค้ดเส้นเดียวกัน (lib/pages/progress/progress_page.dart)
async function submitProof(req, res, quest, photo, kind, checkIn) {
  const now = new Date();
  const submission = await QuestSubmission.create({
    userId: req.userId,
    questId: quest._id,
    kind,
    checkIn: checkIn
      ? { daysDone: checkIn.daysDone, durationDays: checkIn.durationDays, finished: checkIn.finished }
      : undefined,
    photoData: photo.data,
    photoContentType: photo.contentType,
    photoHash: photo.hash,
    details: req.proofDetails || undefined,
    status: 'approved',
    decidedBy: 'instant',
    decidedAt: now,
  });

  // streak ก่อนให้รางวัล — awardQuest อ่าน user ใหม่เองหลังจากนี้
  const user = await User.findById(req.userId).select('-avatarData');
  if (!user) return res.status(404).json({ message: 'User not found' });
  const streakMilestone = await applyStreakNow(user);

  const { owner, combo } = await awardSubmission(submission, quest);
  if (!owner) return res.status(404).json({ message: 'User not found' });
  const bingo = owner.bingo || null;
  const xp = owner.user.xp;

  res.status(201).json({
    message: checkIn && !checkIn.finished ? 'Checked in' : 'Quest completed',
    status: 'completed',
    submissionId: submission._id,
    earned: { points: owner.reward.points, xp: owner.reward.xp },
    newAchievements: owner.newAchievements || [],
    streakMilestone,
    checkIn,
    combo: combo && { ...combo, nextNewMultiplier: nextNewMultiplier(combo.distinctToday) },
    bingo,
    user: {
      level: progression.levelFromXp(xp + (bingo ? bingo.xp : 0)),
      xp: xp + (bingo ? bingo.xp : 0),
      points: owner.user.points + (bingo ? bingo.points : 0),
    },
  });
}

module.exports = router;
