const express = require('express');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const FridgeItem = require('../models/FridgeItem');
const Party = require('../models/Party');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const progression = require('../utils/progression');
const { syncAchievements } = require('../utils/achievements');
const { notifyQuestCompleted } = require('../utils/notifications');
const { startOfToday, todayKey } = require('../utils/questDay');
const crypto = require('crypto');

const router = express.Router();

// เลือก quest 1 อันจากกลุ่มสุ่มแบบ "สุ่มแต่คงที่"
//
// ทำไมต้องคงที่: ถ้าสุ่มใหม่ทุกครั้งที่เรียก API ผู้ใช้จะดึงรีเฟรชรัวๆ จนได้อันที่คะแนนสูงสุด
// และลิสต์จะเปลี่ยนไปมาต่อหน้าต่อตาซึ่งดูเหมือนแอพพัง
// เลยใช้ hash ของ (userId + วันที่ + ชื่อกลุ่ม) เป็นตัวเลือก -> คนละคนได้คนละอัน,
// คนเดิมได้อันเดิมทั้งวัน, พอข้ามเที่ยงคืนถึงจะเปลี่ยน
const pickFromPool = (pool, userId, poolName) => {
  const seed = `${userId}-${todayKey()}-${poolName}`;
  const hash = crypto.createHash('sha256').update(seed).digest();
  return pool[hash.readUInt32BE(0) % pool.length];
};

// @route   GET /api/quests
// @desc    ลิสต์ quest ที่เปิดใช้งานอยู่ + บอกด้วยว่า quest รายวันอันไหนวันนี้ทำไปแล้ว
router.get('/', authMiddleware, async (req, res) => {
  try {
    const allQuests = await Quest.find({ isActive: true }).sort({ createdAt: 1 });

    // แยก quest ที่อยู่กลุ่มสุ่มออกมา แล้วเอาแค่กลุ่มละ 1 อัน
    const pools = new Map();
    const quests = [];
    for (const q of allQuests) {
      if (!q.randomPool) {
        quests.push(q);
        continue;
      }
      if (!pools.has(q.randomPool)) pools.set(q.randomPool, []);
      pools.get(q.randomPool).push(q);
    }
    for (const [poolName, poolQuests] of pools) {
      quests.push(pickFromPool(poolQuests, req.userId, poolName));
    }

    // ดึงประวัติของวันนี้มาทีเดียว แล้วค่อย map ว่า quest ไหนทำไปแล้ว (ไม่ query ทีละ quest)
    const todayHistory = await QuestHistory.find({
      userId: req.userId,
      completedAt: { $gte: startOfToday() },
    }).select('questId');

    const doneToday = new Set(todayHistory.map((h) => h.questId.toString()));

    // party quest ตอนนี้ไม่มี "เข้าร่วม/ยังไม่เข้าร่วม" ต่อ quest แล้ว — เปลี่ยนเป็นสร้าง/เข้าร่วม
    // "ห้อง" (Party) แทน เลยแค่บอกว่ามีกี่ห้องที่ยังเปิดรับอยู่ (openPartyCount) ให้การ์ดโชว์เฉยๆ
    // ยิงทีเดียวสำหรับทุก party quest ไม่ query ทีละอัน
    const partyQuestIds = quests.filter((q) => q.type === 'party').map((q) => q._id);
    const openPartyCounts = new Map();

    if (partyQuestIds.length > 0) {
      const counts = await Party.aggregate([
        { $match: { questId: { $in: partyQuestIds }, status: 'open' } },
        { $group: { _id: '$questId', count: { $sum: 1 } } },
      ]);
      for (const c of counts) openPartyCounts.set(c._id.toString(), c.count);
    }

    res.json({
      quests: quests.map((q) => {
        const id = q._id.toString();
        return {
          id: q._id,
          title: q.title,
          description: q.description,
          detail: q.detail,
          imageKey: q.imageKey,
          category: q.category,
          type: q.type,
          difficulty: q.difficulty,
          impact: q.impact,
          scorePoints: q.scorePoints,
          xpReward: q.xpReward,
          co2SavedKg: q.co2SavedKg,
          isDaily: q.isDaily,
          actionKey: q.actionKey,
          randomPool: q.randomPool,
          completedToday: doneToday.has(id),
          // ---- เฉพาะ party quest ----
          // location/capacity ตรงนี้เป็นแค่ค่า default ให้ฟอร์มสร้างห้องดึงไปเติม
          // (ห้องจริงแต่ละห้องนัดคนละเวลา/สถานที่กันได้ ดูรายละเอียดที่ Party model)
          location: q.location,
          capacity: q.capacity,
          minLevelToHost: q.minLevelToHost,
          openPartyCount: openPartyCounts.get(id) || 0,
        };
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

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const history = await QuestHistory.create({
      userId: user._id,
      questId: quest._id,
      pointsEarned: quest.scorePoints,
      xpEarned: quest.xpReward,
    });

    user.points += quest.scorePoints;
    user.xp += quest.xpReward;
    // level เป็น cache ของ xp — คำนวณใหม่ทุกครั้งที่ xp เปลี่ยน
    // ส่วน user.rank ปล่อยให้ GET /auth/me คิดสดจาก season XP เอา (ไม่ต้อง query season ตรงนี้)
    user.level = progression.levelFromXp(user.xp);
    await user.save();

    // เช็คเหรียญหลังบันทึกประวัติแล้ว — quest ที่เพิ่งทำต้องถูกนับด้วย
    const newAchievements = await syncAchievements(user._id);

    // แจ้งเตือนว่าทำเควสสำเร็จ — ไม่ทำให้ทั้ง request พังถ้าสร้างแจ้งเตือนไม่สำเร็จ
    try {
      await notifyQuestCompleted(user._id, quest, history._id);
    } catch (notifyErr) {
      console.error('สร้างแจ้งเตือนทำเควสสำเร็จไม่สำเร็จ:', notifyErr.message);
    }

    res.json({
      message: 'Quest completed',
      earned: {
        points: quest.scorePoints,
        xp: quest.xpReward,
      },
      // เหรียญที่เพิ่งปลดล็อกรอบนี้ (ปกติเป็น array ว่าง) — แอพเอาไปเด้งแจ้งเตือน
      newAchievements,
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
