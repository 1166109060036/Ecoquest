const express = require('express');
const Party = require('../models/Party');
const PartyMember = require('../models/PartyMember');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const progression = require('../utils/progression');
const { syncAchievements } = require('../utils/achievements');
const { notifyQuestCompleted } = require('../utils/notifications');
const { getUserBonusesMap, applyBonuses } = require('../utils/upgrades');
const { withEnergyBoosts } = require('../utils/inventory');
const { startOfToday } = require('../utils/questDay');
const { avatarUrlFor } = require('../utils/avatar');
const { requiredMembers, canStart, canComplete } = require('../utils/partyGate');
const { syncPartyRoomForUser } = require('../sockets');

const router = express.Router();

// แปลง party (ต้อง populate questId มาก่อนแล้ว) + สมาชิก ให้อยู่ในรูปที่แอพเอาไปโชว์ได้เลย
const toPartyPayload = async (party, userId) => {
  const members = await PartyMember.find({ partyId: party._id })
    .sort({ isLeader: -1, joinedAt: 1 }) // หัวหน้าขึ้นก่อน แล้วเรียงตามลำดับที่เข้าร่วม
    // avatarContentType/avatarUpdatedAt เอามาแค่สร้าง avatarUrl ไม่เอา avatarData ตัวจริงมาด้วย
    .populate('userId', 'displayName level rank avatarContentType avatarUpdatedAt');

  const quest = party.questId; // populate ไว้แล้วตอนดึง party มา
  // กันกรณี user ถูกลบไปแล้วแต่ record ยังค้าง — นับเฉพาะสมาชิกที่ยังมีบัญชีอยู่จริง (ตรงกับที่โชว์ในลิสต์)
  const validMembers = members.filter((m) => m.userId);
  const memberCount = validMembers.length;

  return {
    id: party._id,
    name: party.name,
    status: party.status,
    startedAt: party.startedAt,
    completedAt: party.completedAt,
    eventDate: party.eventDate,
    location: party.location,
    capacity: party.capacity,
    isLeader: party.leaderId.toString() === String(userId),
    memberCount,
    requiredMembers: requiredMembers(party),
    // canStart/canComplete ให้แอพโชว์/ซ่อนปุ่มได้เลยโดยไม่ต้อง mirror กฎเอง — backend ยังเช็คซ้ำทุก
    // request จริงอยู่ดี ไม่ได้เชื่อค่าพวกนี้จาก client ตอนกด action
    canStart: canStart(party, memberCount).ok,
    startBlockedReason: canStart(party, memberCount).reason,
    canComplete: canComplete(party).ok,
    completeBlockedReason: canComplete(party).reason,
    quest: quest
      ? {
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
        }
      : null,
    members: validMembers
      .map((m) => ({
        userId: m.userId._id,
        displayName: m.userId.displayName,
        avatarUrl: avatarUrlFor(m.userId),
        level: m.userId.level,
        rank: m.userId.rank,
        isLeader: m.isLeader,
        isMe: m.userId._id.toString() === String(userId),
        joinedAt: m.joinedAt,
      })),
  };
};

// @route   GET /api/party
// @desc    ห้องที่ user กำลังอยู่ตอนนี้ (เข้าร่วมได้ทีละห้องเดียวตามดีไซน์)
router.get('/', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId }).sort({ joinedAt: -1 });
    if (!membership) return res.json({ party: null });

    const party = await Party.findById(membership.partyId).populate('questId');
    if (!party) {
      // ห้องถูกลบไปแล้วแต่ยังมี record สมาชิกค้างอยู่ — เก็บกวาดทิ้งแล้วตอบว่าไม่มีห้อง
      await PartyMember.deleteMany({ partyId: membership.partyId });
      return res.json({ party: null });
    }

    res.json({ party: await toPartyPayload(party, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/party/rooms
// @desc    ลิสต์ห้องที่ยังเปิดรับสมาชิกอยู่ ให้ผู้เล่นเลือกเข้าร่วม
router.get('/rooms', authMiddleware, async (req, res) => {
  try {
    const parties = await Party.find({ status: 'open' })
      .sort({ eventDate: 1 })
      .populate('questId');

    // นับจำนวนสมาชิกทีเดียวทุกห้อง ไม่ query ทีละห้อง
    const partyIds = parties.map((p) => p._id);
    const counts = await PartyMember.aggregate([
      { $match: { partyId: { $in: partyIds } } },
      { $group: { _id: '$partyId', count: { $sum: 1 } } },
    ]);
    const memberCounts = new Map(counts.map((c) => [c._id.toString(), c.count]));

    const rooms = parties
      // quest แม่แบบถูกปิด/ลบไปแล้ว -> ไม่โชว์ในลิสต์ให้เข้าร่วมใหม่ (leader ยังออกห้องได้ผ่าน GET /party)
      .filter((p) => p.questId && p.questId.isActive)
      .map((p) => {
        const memberCount = memberCounts.get(p._id.toString()) || 0;
        return {
          id: p._id,
          name: p.name,
          eventDate: p.eventDate,
          location: p.location,
          capacity: p.capacity,
          memberCount,
          isFull: p.capacity > 0 && memberCount >= p.capacity,
          quest: {
            id: p.questId._id,
            title: p.questId.title,
            imageKey: p.questId.imageKey,
            category: p.questId.category,
            difficulty: p.questId.difficulty,
            scorePoints: p.questId.scorePoints,
            xpReward: p.questId.xpReward,
          },
        };
      });

    res.json({ rooms });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party
// @desc    สร้างห้องใหม่จาก party quest ที่มีอยู่แล้ว — ผู้สร้างเป็นหัวหน้าห้องทันที
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { questId, name, eventDate, location, capacity } = req.body;

    const quest = await Quest.findById(questId);
    if (!quest || !quest.isActive) {
      return res.status(404).json({ message: 'Quest not found' });
    }
    if (quest.type !== 'party') {
      return res.status(400).json({ message: 'This quest cannot be used to create a party' });
    }

    const existing = await PartyMember.findOne({ userId: req.userId });
    if (existing) {
      return res
        .status(409)
        .json({ message: 'You are already in a party. Leave it first.' });
    }

    // -avatarData กัน Buffer รูปโปรไฟล์ถูกดึงมาโดยไม่ได้ใช้ (route นี้ไม่เกี่ยวกับรูปเลย)
    const user = await User.findById(req.userId).select('-avatarData');
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.level < quest.minLevelToHost) {
      return res.status(403).json({
        message: `You need to reach level ${quest.minLevelToHost} to host this event`,
      });
    }

    // ---- validate ฟอร์ม ----
    const trimmedName = (name || '').toString().trim();
    if (!trimmedName) {
      return res.status(400).json({ message: 'Please enter a room name' });
    }

    const parsedDate = new Date(eventDate);
    if (!eventDate || Number.isNaN(parsedDate.getTime())) {
      return res.status(400).json({ message: 'Please pick a valid event date and time' });
    }
    if (parsedDate.getTime() <= Date.now()) {
      return res.status(400).json({ message: 'Event date must be in the future' });
    }

    // capacity เป็น optional — ไม่ใส่มาก็ใช้ค่า default ของ quest
    // ⚠️ บังคับต้องระบุอย่างน้อย 2 คนเสมอสำหรับห้องใหม่ (เลิกรองรับ "ไม่จำกัดคน" ผ่าน capacity: 0)
    // เพราะเงื่อนไข "สมาชิกครบ" ก่อนเริ่มอีเวนต์ (utils/partyGate.js#canStart) นิยามไม่ได้ถ้าไม่จำกัด —
    // ห้องเก่าที่ยังมี capacity: 0 ค้างอยู่ใน DB ไม่กระทบ ยังใช้ MIN_PARTY_MEMBERS แทนได้ตามปกติ
    let parsedCapacity = capacity === undefined || capacity === null ? quest.capacity : Number(capacity);
    if (!Number.isInteger(parsedCapacity)) {
      return res.status(400).json({ message: 'Capacity must be a whole number' });
    }
    if (parsedCapacity < 2) {
      return res.status(400).json({ message: 'Capacity must allow at least 2 members' });
    }

    const party = await Party.create({
      questId: quest._id,
      leaderId: req.userId,
      name: trimmedName,
      eventDate: parsedDate,
      location: (location || '').toString().trim() || quest.location,
      capacity: parsedCapacity,
    });

    await PartyMember.create({
      partyId: party._id,
      userId: req.userId,
      isLeader: true,
    });
    // ให้ session ที่เปิดค้างอยู่ (ถ้ามี) join ห้องแชทปาร์ตี้ทันที ไม่ต้องรอ reconnect
    syncPartyRoomForUser(req.userId, party._id, 'join');

    const populated = await Party.findById(party._id).populate('questId');
    res.status(201).json({
      message: 'Party created',
      party: await toPartyPayload(populated, req.userId),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party/start
// @desc    หัวหน้าห้องกด "เริ่มภารกิจ" — ด่านที่ต้องผ่านก่อนกด Complete ได้ (กันปั๊มคะแนน สร้างห้อง
//          แล้วกดจบทันที) กดได้ต่อเมื่อถึงเวลานัด (eventDate) แล้ว และสมาชิกครบตาม requiredMembers
router.post('/start', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId });
    if (!membership) {
      return res.status(400).json({ message: 'You are not in a party' });
    }

    const current = await Party.findById(membership.partyId);
    if (!current) return res.status(404).json({ message: 'Party not found' });
    if (current.leaderId.toString() !== String(req.userId)) {
      return res.status(403).json({ message: 'Only the party leader can start this event' });
    }

    // เช็คเงื่อนไขทั้งหมด "ก่อน" latch เสมอ — ถ้าเช็คทีหลังจะได้ห้องที่ status ถูก flip ไปแล้วแต่ไม่ผ่าน
    // เงื่อนไขจริง (บั๊กแบบเดียวกับที่เคยมีตอนเช็ค quest.isActive หลัง latch ใน /complete)
    const memberCount = await PartyMember.countDocuments({ partyId: current._id });
    const check = canStart(current, memberCount);
    if (!check.ok) {
      return res.status(409).json({ message: check.reason });
    }

    // latch เปลี่ยนสถานะแบบ atomic (compare-and-swap) — กันกดซ้อน/กดซ้ำเหมือนที่ /complete ใช้อยู่แล้ว
    const party = await Party.findOneAndUpdate(
      { _id: current._id, leaderId: req.userId, status: 'open' },
      { status: 'started', startedAt: new Date() },
      { new: true }
    ).populate('questId');

    if (!party) {
      return res.status(409).json({ message: 'This event is not open anymore' });
    }

    res.json({
      message: 'Event started',
      party: await toPartyPayload(party, req.userId),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party/join/:partyId
// @desc    เข้าร่วมห้องที่มีคนสร้างไว้แล้ว
router.post('/join/:partyId', authMiddleware, async (req, res) => {
  try {
    const party = await Party.findById(req.params.partyId).populate('questId');
    if (!party) {
      return res.status(404).json({ message: 'Party not found' });
    }
    if (party.status === 'started') {
      return res.status(409).json({ message: 'This event has already started' });
    }
    if (party.status !== 'open') {
      return res.status(409).json({ message: 'This event has already finished' });
    }
    if (!party.questId || !party.questId.isActive) {
      return res.status(409).json({ message: 'This event is no longer available' });
    }

    const existing = await PartyMember.findOne({ userId: req.userId });
    if (existing) {
      if (existing.partyId.toString() === party._id.toString()) {
        return res.status(409).json({ message: 'You have already joined this party' });
      }
      return res
        .status(409)
        .json({ message: 'You are already in another party. Leave it first.' });
    }

    if (party.capacity > 0) {
      const memberCount = await PartyMember.countDocuments({ partyId: party._id });
      if (memberCount >= party.capacity) {
        return res.status(409).json({ message: 'This party is already full' });
      }
    }

    try {
      await PartyMember.create({
        partyId: party._id,
        userId: req.userId,
        isLeader: false,
      });
    } catch (err) {
      // เผื่อ 2 request วิ่งชนกันพอดี ตัว unique index จะกันซ้ำให้อีกที
      if (err.code === 11000) {
        return res.status(409).json({ message: 'You have already joined this party' });
      }
      throw err;
    }
    syncPartyRoomForUser(req.userId, party._id, 'join');

    res.status(201).json({
      message: 'Joined the party',
      party: await toPartyPayload(party, req.userId),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party/leave
// @desc    ออกจากห้อง — ถ้าห้อง completed อยู่แล้วก็แค่ dismiss ไปเฉยๆ
//          ถ้าห้องยัง open และคนออกเป็นหัวหน้า จะเลื่อนคนถัดไปเป็นหัวหน้าแทน
//          ถ้าไม่เหลือใครเลยก็ลบห้องทิ้ง
router.post('/leave', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId });
    if (!membership) {
      return res.status(400).json({ message: 'You are not in a party' });
    }

    const { partyId, isLeader } = membership;
    await PartyMember.deleteOne({ _id: membership._id });
    syncPartyRoomForUser(req.userId, partyId, 'leave');

    const remaining = await PartyMember.findOne({ partyId }).sort({ joinedAt: 1 });

    if (!remaining) {
      // ห้องว่างแล้ว ไม่มีเหตุผลจะเก็บไว้
      await Party.deleteOne({ _id: partyId });
    } else if (isLeader) {
      // หัวหน้าออกไปก่อน -> เลื่อนคนที่เข้าร่วมนานที่สุดถัดมาเป็นหัวหน้าแทน
      remaining.isLeader = true;
      await remaining.save();
      await Party.updateOne({ _id: partyId }, { leaderId: remaining.userId });
    }

    res.json({ message: 'Left the party' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/party/complete
// @desc    หัวหน้าห้องกดจบอีเวนต์ — ทุกคนในห้อง (รวมหัวหน้า) ได้คะแนน/XP พร้อมกัน
//          ทำได้วันละครั้งต่อคนต่อ quest เหมือน quest รายวันทั่วไป
router.post('/complete', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId });
    if (!membership) {
      return res.status(400).json({ message: 'You are not in a party' });
    }

    const current = await Party.findById(membership.partyId).populate('questId');
    if (!current) return res.status(404).json({ message: 'Party not found' });
    if (current.leaderId.toString() !== String(req.userId)) {
      return res.status(403).json({ message: 'Only the party leader can complete this event' });
    }

    // เช็คเงื่อนไข (ต้องผ่าน /start มาก่อน + รอครบ 15 นาที) กับเช็ค quest ยังเปิดใช้งานอยู่ไหม "ก่อน" latch
    // เสมอ — ถ้าเช็คทีหลัง (โค้ดเดิมเคยเช็ค quest.isActive หลัง latch) ห้องจะถูก flip เป็น completed ทิ้ง
    // ไปโดยไม่มีใครได้คะแนนเลยถ้าเงื่อนไขไม่ผ่าน
    const check = canComplete(current);
    if (!check.ok) {
      return res.status(409).json({ message: check.reason });
    }
    const quest = current.questId;
    if (!quest || !quest.isActive) {
      return res.status(409).json({ message: 'This quest is no longer available' });
    }

    // ล็อกสถานะเป็น completed ใน query เดียว (findOneAndUpdate) — ถ้ามีคนกดซ้อนหรือกดซ้ำ
    // request รอบถัดไปจะหา party ที่ status ยังเป็น 'started' ไม่เจอแล้ว กันคะแนนซ้ำได้แน่นอน
    const party = await Party.findOneAndUpdate(
      { _id: current._id, leaderId: req.userId, status: 'started' },
      { status: 'completed', completedAt: new Date() },
      { new: true }
    ).populate('questId');

    if (!party) {
      return res.status(409).json({ message: 'This event is already completed' });
    }

    const members = await PartyMember.find({ partyId: party._id });
    const startOfDay = startOfToday();

    // ดึง upgrade ของสมาชิกทุกคนมาทีเดียวก่อนเข้าลูป ไม่ query ต่อคนต่อรอบ
    // แต่ละคนมี upgrade ไม่เท่ากัน เลยต้องคิด bonus แยกรายคน ไม่ใช่ค่าเดียวทั้งห้อง
    const bonusesMap = await getUserBonusesMap(members.map((m) => m.userId));

    let awardedCount = 0;
    let leaderReward = { points: 0, xp: 0 };
    let leaderNewAchievements = [];

    for (const m of members) {
      // เควส party ทำซ้ำได้วันละครั้งเหมือน quest รายวัน — ใครทำเควสนี้ไปแล้ววันนี้ ข้ามไป
      const already = await QuestHistory.findOne({
        userId: m.userId,
        questId: quest._id,
        completedAt: { $gte: startOfDay },
      });
      if (already) continue;

      // -avatarData กันดึง Buffer รูปโปรไฟล์มาทุกคนในลูปนี้โดยไม่ได้ใช้ (ยิ่งห้องใหญ่ยิ่งเปลือง)
      const user = await User.findById(m.userId).select('-avatarData');
      if (!user) continue; // user ถูกลบไปแล้ว

      const baseBonuses = bonusesMap.get(String(user._id)) || {
        pointPct: 0,
        xpPct: 0,
        rankPct: 0,
        partyPct: 0,
        questSlots: 0,
      };
      // withEnergyBoosts เติมตัวคูณจากไอเทม Energy ที่ยังไม่หมดอายุ (ถ้ามี) — ใช้ user ที่โหลดสดแล้วด้านบน
      // ไม่ query ซ้ำ (Green Energy คือตัวที่มีผลตรงนี้จริงๆ เพราะเควสในลูปนี้เป็น party เสมอ)
      const bonuses = withEnergyBoosts(baseBonuses, user);
      const reward = applyBonuses(bonuses, quest);

      const history = await QuestHistory.create({
        userId: user._id,
        questId: quest._id,
        pointsEarned: reward.points,
        // ⚠️ เก็บ rankXp ไม่ใช่ reward.xp — ใช้คิด Rank แยกจาก user.xp ที่คิด Level (ดู utils/upgrades.js)
        xpEarned: reward.rankXp,
      });

      user.points += reward.points;
      user.xp += reward.xp;
      user.level = progression.levelFromXp(user.xp);
      await user.save();

      const unlocked = await syncAchievements(user._id);
      awardedCount += 1;

      // สมาชิกทุกคนที่ได้คะแนนรอบนี้ ไม่ใช่แค่หัวหน้า ต้องได้แจ้งเตือนของตัวเอง
      try {
        await notifyQuestCompleted(user._id, quest, history._id, reward.points);
      } catch (notifyErr) {
        console.error('สร้างแจ้งเตือนทำเควสสำเร็จไม่สำเร็จ:', notifyErr.message);
      }

      if (String(user._id) === String(req.userId)) {
        leaderReward = { points: reward.points, xp: reward.xp };
        leaderNewAchievements = unlocked;
      }
    }

    res.json({
      message: 'Event completed',
      earned: leaderReward,
      newAchievements: leaderNewAchievements,
      awardedCount,
      party: await toPartyPayload(party, req.userId),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
