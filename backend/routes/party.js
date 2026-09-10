const express = require('express');
const Quest = require('../models/Quest');
const PartyMember = require('../models/PartyMember');
const QuestHistory = require('../models/QuestHistory');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// แปลง quest + สมาชิก ให้อยู่ในรูปที่แอพเอาไปโชว์ได้เลย
const toPartyPayload = async (quest, userId) => {
  const members = await PartyMember.find({ questId: quest._id })
    .sort({ isLeader: -1, joinedAt: 1 }) // หัวหน้าขึ้นก่อน แล้วเรียงตามลำดับที่เข้าร่วม
    .populate('userId', 'displayName level rank');

  // เคยทำอีเวนต์นี้สำเร็จไปแล้วหรือยัง (party quest ทำได้ครั้งเดียว ไม่ใช่รายวัน)
  const completed = await QuestHistory.findOne({ userId, questId: quest._id });

  return {
    quest: {
      id: quest._id,
      title: quest.title,
      description: quest.description,
      detail: quest.detail,
      imageKey: quest.imageKey,
      category: quest.category,
      difficulty: quest.difficulty,
      impact: quest.impact,
      scorePoints: quest.scorePoints,
      xpReward: quest.xpReward,
      co2SavedKg: quest.co2SavedKg,
      eventDate: quest.eventDate,
      location: quest.location,
      capacity: quest.capacity,
      completed: !!completed,
    },
    members: members
      // กันกรณี user ถูกลบไปแล้วแต่ record ยังค้าง — ไม่ให้ทั้งหน้าพัง
      .filter((m) => m.userId)
      .map((m) => ({
        userId: m.userId._id,
        displayName: m.userId.displayName,
        level: m.userId.level,
        rank: m.userId.rank,
        isLeader: m.isLeader,
        isMe: m.userId._id.toString() === String(userId),
        joinedAt: m.joinedAt,
      })),
  };
};

// @route   GET /api/party
// @desc    ปาร์ตี้ที่ user กำลังอยู่ (รายละเอียดอีเวนต์ + สมาชิกทั้งหมด)
// คืน party: null ถ้ายังไม่ได้เข้าร่วมอีเวนต์ไหนเลย
router.get('/', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId }).sort({ joinedAt: -1 });
    if (!membership) {
      return res.json({ party: null });
    }

    const quest = await Quest.findById(membership.questId);
    if (!quest) {
      // อีเวนต์ถูกลบไปแล้ว — เก็บกวาด record ที่ค้างแล้วบอกว่าไม่มีปาร์ตี้
      await PartyMember.deleteMany({ questId: membership.questId });
      return res.json({ party: null });
    }

    res.json({ party: await toPartyPayload(quest, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party/join/:questId
// @desc    เข้าร่วม party quest
router.post('/join/:questId', authMiddleware, async (req, res) => {
  try {
    const quest = await Quest.findById(req.params.questId);
    if (!quest || !quest.isActive) {
      return res.status(404).json({ message: 'Quest not found' });
    }
    if (quest.type !== 'party') {
      return res.status(400).json({ message: 'This quest is not a party quest' });
    }

    // อยู่ปาร์ตี้อื่นอยู่แล้ว — ต้องออกจากอันเดิมก่อน (ดีไซน์: อยู่ได้ทีละปาร์ตี้)
    const existing = await PartyMember.findOne({ userId: req.userId });
    if (existing) {
      if (existing.questId.toString() === quest._id.toString()) {
        return res.status(409).json({ message: 'You have already joined this event' });
      }
      return res.status(409).json({
        message: 'You are already in another party. Leave it first.',
      });
    }

    const memberCount = await PartyMember.countDocuments({ questId: quest._id });
    if (quest.capacity > 0 && memberCount >= quest.capacity) {
      return res.status(409).json({ message: 'This event is already full' });
    }

    try {
      await PartyMember.create({
        questId: quest._id,
        userId: req.userId,
        // คนแรกที่เข้าร่วมได้เป็นหัวหน้าปาร์ตี้
        isLeader: memberCount === 0,
      });
    } catch (err) {
      // ชน unique index = กดเข้าร่วมรัวๆ พร้อมกัน ไม่ถือว่าพัง
      if (err.code !== 11000) throw err;
      return res.status(409).json({ message: 'You have already joined this event' });
    }

    res.status(201).json({
      message: 'Joined the party',
      party: await toPartyPayload(quest, req.userId),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party/leave
// @desc    ออกจากปาร์ตี้ปัจจุบัน
router.post('/leave', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId });
    if (!membership) {
      return res.status(400).json({ message: 'You are not in a party' });
    }

    const { questId, isLeader } = membership;
    await PartyMember.deleteOne({ _id: membership._id });

    // หัวหน้าออก -> ยกตำแหน่งให้คนที่เข้าร่วมถัดไป ปาร์ตี้จะได้ไม่ไร้หัวหน้า
    if (isLeader) {
      const next = await PartyMember.findOne({ questId }).sort({ joinedAt: 1 });
      if (next) {
        next.isLeader = true;
        await next.save();
      }
    }

    res.json({ message: 'Left the party' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
