const express = require('express');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const QuestProgress = require('../models/QuestProgress');
const FridgeItem = require('../models/FridgeItem');
const Party = require('../models/Party');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const progression = require('../utils/progression');
const { syncAchievements } = require('../utils/achievements');
const { notifyQuestCompleted, notifyStreakMilestone } = require('../utils/notifications');
const { getUserBonuses, applyBonuses, BASE_VISIBLE_QUESTS } = require('../utils/upgrades');
const { withEnergyBoosts } = require('../utils/inventory');
const { startOfToday } = require('../utils/questDay');
const { applyDailyQuestCompletion } = require('../utils/streak');
const { selectVisibleQuests } = require('../utils/questSelection');

const router = express.Router();

// แปลง quest template + bonus ของ user เป็น payload ที่ส่งให้แอพ — ใช้ร่วมกันทั้ง GET / และ
// GET /progress เพื่อให้ scorePoints/xpReward ที่โชว์ผ่าน applyBonuses ตรงกันเป๊ะทั้ง 2 หน้า
const toQuestPayload = (quest, bonuses, { completedToday, inProgress, startedAt, openPartyCount } = {}) => {
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
    completedToday: Boolean(completedToday),
    // เควสที่ user กด Start ไว้แต่ยังไม่ Complete — ดู models/QuestProgress.js
    inProgress: Boolean(inProgress),
    startedAt: startedAt || null,
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
    const allQuests = await Quest.find({ isActive: true }).sort({ sortOrder: 1, createdAt: 1 });

    // ดึงมาแค่ 3 ฟิลด์ boost expiry ก็พอ ไม่ใช่ user ทั้งก้อน (กัน avatarData Buffer ด้วยในตัว
    // เพราะไม่ได้ select มันมา) — ใส่ withEnergyBoosts ตรงนี้เพื่อให้การ์ดเควสโชว์ตัวเลขหลังคูณบัฟ
    // Energy ที่ยังไม่หมดอายุด้วย ไม่งั้นการ์ดโชว์ตัวเลขนึง แต่กดทำจริงได้อีกตัวเลข ดูเหมือนบั๊ก
    const boostUser = await User.findById(req.userId).select(
      'redEnergyExpiresAt blueEnergyExpiresAt greenEnergyExpiresAt'
    );
    const bonuses = withEnergyBoosts(await getUserBonuses(req.userId), boostUser);
    // upgrade "Quest Unlock" เพิ่มจำนวน solo quest ที่เห็นได้ — วิธีสุ่ม/ปักหมุดดู utils/questSelection.js
    const soloLimit = BASE_VISIBLE_QUESTS + bonuses.questSlots;
    const visibleQuests = selectVisibleQuests(allQuests, req.userId, soloLimit);

    // ดึงประวัติของวันนี้ + เควสที่กำลัง Start ค้างอยู่มาทีเดียว แล้วค่อย map (ไม่ query ทีละ quest)
    const [todayHistory, progressRows] = await Promise.all([
      QuestHistory.find({
        userId: req.userId,
        completedAt: { $gte: startOfToday() },
      }).select('questId'),
      QuestProgress.find({ userId: req.userId }).select('questId'),
    ]);

    const doneToday = new Set(todayHistory.map((h) => h.questId.toString()));
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
        return toQuestPayload(q, bonuses, {
          completedToday: doneToday.has(id),
          inProgress: inProgressIds.has(id),
          openPartyCount: openPartyCounts.get(id) || 0,
        });
      }),
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

    const history = await QuestHistory.find({ userId: req.userId })
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

    res.json({
      // ⚠️ จงใจไม่ใช้ selectVisibleQuests (สุ่มรายวัน + จำกัดจำนวน) แบบ GET / —
      // เควสที่ start ไปแล้วต้องโผล่ในหน้านี้เสมอ ไม่ว่าจะโดนสุ่มไม่ติดหรือโดนลิมิตตัดในวันถัดไป
      // ไม่งั้นผู้ใช้จะค้างเควสที่ทำต่อไม่ได้เลย
      progress: activeRows.map((p) =>
        toQuestPayload(p.questId, bonuses, {
          // แถว progress มีอยู่ได้เฉพาะตอนยังไม่ complete เท่านั้น (ดู models/QuestProgress.js)
          completedToday: false,
          inProgress: true,
          startedAt: p.startedAt,
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

    // quest รายวันที่ทำไปแล้ววันนี้ — start ใหม่ไม่ได้ (สม่ำเสมอกับ gate ของ /complete)
    if (quest.isDaily) {
      const alreadyDone = await QuestHistory.findOne({
        userId: req.userId,
        questId: quest._id,
        completedAt: { $gte: startOfToday() },
      });
      if (alreadyDone) {
        return res.status(409).json({ message: 'You have already completed this quest today' });
      }
    }

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
// @desc    ทำ quest สำเร็จ — บันทึกประวัติ + บวก points/XP + อัปเดต level
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

    // quest รายวัน — ทำซ้ำในวันเดียวกันไม่ได้
    if (quest.isDaily) {
      const alreadyDone = await QuestHistory.findOne({
        userId: req.userId,
        questId: quest._id,
        completedAt: { $gte: startOfToday() },
      });
      if (alreadyDone) {
        return res.status(409).json({ message: 'You have already completed this quest today' });
      }
    }

    // quest ที่ต้องทำ action จริงในแอพ — ต้องเช็คว่าทำจริงแล้วก่อนให้คะแนน
    // ไม่งั้นแค่กดปุ่ม Start ก็ได้คะแนนเลย ซึ่งไม่ตรงกับดีไซน์ของ Mini Quest
    if (quest.actionKey === 'fridge_check') {
      const savedToday = await FridgeItem.findOne({
        userId: req.userId,
        addedAt: { $gte: startOfToday() },
      });
      if (!savedToday) {
        return res.status(400).json({
          message: 'Save your fridge items first to complete this quest',
        });
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

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาทุกครั้งที่ทำเควสสำเร็จโดยไม่ได้ใช้
    const user = await User.findById(req.userId).select('-avatarData');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // คำนวณครั้งเดียวแล้วใช้ค่าเดิมทุกจุดด้านล่าง (ประวัติ, ยอดผู้ใช้, response, แจ้งเตือน)
    // ไม่งั้นตัวเลขที่บันทึกกับที่โชว์จะไม่ตรงกัน
    // withEnergyBoosts เติมตัวคูณจากไอเทม Red/Blue/Green Energy ที่ยังไม่หมดอายุ (ถ้ามี) เข้าไปด้วย
    const bonuses = withEnergyBoosts(await getUserBonuses(user._id), user);
    const reward = applyBonuses(bonuses, quest);

    const history = await QuestHistory.create({
      userId: user._id,
      questId: quest._id,
      pointsEarned: reward.points,
      xpEarned: reward.xp,
    });

    user.points += reward.points;
    user.xp += reward.xp;
    // level เป็น cache ของ xp — คำนวณใหม่ทุกครั้งที่ xp เปลี่ยน
    user.level = progression.levelFromXp(user.xp);
    // ยอดรวมตลอดชีพ +1 เสมอ ไม่มีทางลดลง (ต่างจาก QuestHistory ที่ลบแถวได้ตอนใช้ Super Energy)
    user.totalQuestsCompleted = (user.totalQuestsCompleted || 0) + 1;
    // อัพเดท Daily Streak ก่อน save — mutate user ในหน่วยความจำ (points/xp เพิ่มเติมถ้าครบ milestone)
    // แล้ว save รวมทีเดียวกับการเปลี่ยนแปลงข้างบน
    const streakMilestone = await applyDailyQuestCompletion(user);
    await user.save();

    // เช็คเหรียญหลังบันทึกประวัติแล้ว — quest ที่เพิ่งทำต้องถูกนับด้วย
    const newAchievements = await syncAchievements(user._id);

    // แจ้งเตือนว่าทำเควสสำเร็จ — ไม่ทำให้ทั้ง request พังถ้าสร้างแจ้งเตือนไม่สำเร็จ
    try {
      await notifyQuestCompleted(user._id, quest, history._id, reward.points);
      if (streakMilestone) {
        await notifyStreakMilestone(user._id, streakMilestone.day, streakMilestone);
      }
    } catch (notifyErr) {
      console.error('สร้างแจ้งเตือนทำเควสสำเร็จไม่สำเร็จ:', notifyErr.message);
    }

    res.json({
      message: 'Quest completed',
      earned: {
        points: reward.points,
        xp: reward.xp,
      },
      // เหรียญที่เพิ่งปลดล็อกรอบนี้ (ปกติเป็น array ว่าง) — แอพเอาไปเด้งแจ้งเตือน
      newAchievements,
      // ไม่ null เฉพาะตอนวันนี้ตรง milestone ของ Daily Streak (7/14/21/30) — แอพเอาไปเด้ง celebrate
      streakMilestone,
      user: {
        level: user.level,
        xp: user.xp,
        points: user.points,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
