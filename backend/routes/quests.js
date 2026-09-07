const express = require('express');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const FridgeItem = require('../models/FridgeItem');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const progression = require('../utils/progression');

const router = express.Router();

// เที่ยงคืนของ "วันนี้" ตามเวลาเครื่อง server
// ⚠️ ถ้าเอาไป deploy บน server ที่ตั้งเป็น UTC เส้นแบ่งวันจะเลื่อนไปจากเวลาไทย/ญี่ปุ่น
// ถ้าจะ deploy จริงควรกำหนด timezone ให้ชัดเจนก่อน
const startOfToday = () => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
};

// @route   GET /api/quests
// @desc    ลิสต์ quest ที่เปิดใช้งานอยู่ + บอกด้วยว่า quest รายวันอันไหนวันนี้ทำไปแล้ว
router.get('/', authMiddleware, async (req, res) => {
  try {
    const quests = await Quest.find({ isActive: true }).sort({ createdAt: 1 });

    // ดึงประวัติของวันนี้มาทีเดียว แล้วค่อย map ว่า quest ไหนทำไปแล้ว (ไม่ query ทีละ quest)
    const todayHistory = await QuestHistory.find({
      userId: req.userId,
      completedAt: { $gte: startOfToday() },
    }).select('questId');

    const doneToday = new Set(todayHistory.map((h) => h.questId.toString()));

    res.json({
      quests: quests.map((q) => ({
        id: q._id,
        title: q.title,
        description: q.description,
        category: q.category,
        type: q.type,
        difficulty: q.difficulty,
        impact: q.impact,
        scorePoints: q.scorePoints,
        xpReward: q.xpReward,
        co2SavedKg: q.co2SavedKg,
        isDaily: q.isDaily,
        actionKey: q.actionKey,
        completedToday: doneToday.has(q._id.toString()),
      })),
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

    await QuestHistory.create({
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

    res.json({
      message: 'Quest completed',
      earned: {
        points: quest.scorePoints,
        xp: quest.xpReward,
      },
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
