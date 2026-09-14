const express = require('express');
const User = require('../models/User');
const Party = require('../models/Party');
const PartyMember = require('../models/PartyMember');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const Achievement = require('../models/Achievement');
const InventoryItem = require('../models/InventoryItem');
const UserUpgrade = require('../models/UserUpgrade');
const FridgeItem = require('../models/FridgeItem');
const Season = require('../models/Season');
const authMiddleware = require('../middleware/auth');
const { adminMiddleware } = require('../middleware/admin');
const progression = require('../utils/progression');
const { MEDALS, syncAchievements } = require('../utils/achievements');
const { ITEMS, withEnergyBoosts } = require('../utils/inventory');
const { UPGRADES, getUserBonuses, applyBonuses } = require('../utils/upgrades');
const { createNotification } = require('../utils/notifications');
const { startOfToday } = require('../utils/questDay');
const { ensureActiveSeason } = require('../utils/seasons');

const router = express.Router();

// ทุก route ในไฟล์นี้เป็นของ QA/dev เท่านั้น — ต้อง login (authMiddleware) + อีเมลอยู่ใน
// ADMIN_EMAILS (adminMiddleware) ทั้งคู่เสมอ ดู middleware/admin.js
router.use(authMiddleware, adminMiddleware);

// ---------------------------------------------------------------------------
// User
// ---------------------------------------------------------------------------

// @route   GET /api/admin/debug/me
// @desc    raw user doc เต็ม (ไม่รวม password/avatarData) ไว้ดู state จริงตอน debug
router.get('/debug/me', async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password -avatarData');
    res.json({ user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/user/stats
// @desc    set points/xp/level ตรงๆ ข้ามการทำเควส — ไม่ส่ง level มา = คำนวณจาก xp ให้อัตโนมัติ
router.post('/user/stats', async (req, res) => {
  try {
    const { points, xp, level } = req.body;
    const update = {};
    if (typeof points === 'number') update.points = points;
    if (typeof xp === 'number') {
      update.xp = xp;
      update.level = typeof level === 'number' ? level : progression.levelFromXp(xp);
    } else if (typeof level === 'number') {
      update.level = level;
    }

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ message: 'Nothing to update' });
    }

    const user = await User.findByIdAndUpdate(req.userId, { $set: update }, { new: true }).select(
      '-password -avatarData'
    );
    res.json({ user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

const BOOST_FIELD = {
  red: 'redEnergyExpiresAt',
  blue: 'blueEnergyExpiresAt',
  green: 'greenEnergyExpiresAt',
};

// @route   POST /api/admin/user/boost
// @desc    เปิดบัฟ Energy สีไหนก็ได้ตรงๆ นานกี่นาทีก็ได้ ไม่ต้องมีไอเทมจริง/ไม่หักจาก inventory
router.post('/user/boost', async (req, res) => {
  try {
    const { color, minutes } = req.body;
    const field = BOOST_FIELD[color];
    if (!field || typeof minutes !== 'number') {
      return res.status(400).json({ message: 'color must be red/blue/green and minutes a number' });
    }

    const expiresAt = new Date(Date.now() + minutes * 60 * 1000);
    await User.updateOne({ _id: req.userId }, { $set: { [field]: expiresAt } });
    res.json({ color, expiresAt });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/user/boost/clear
// @desc    เคลียร์บัฟ Energy ทั้ง 3 สีเป็น null
router.post('/user/boost/clear', async (req, res) => {
  try {
    await User.updateOne(
      { _id: req.userId },
      { $set: { redEnergyExpiresAt: null, blueEnergyExpiresAt: null, greenEnergyExpiresAt: null } }
    );
    res.json({ message: 'Boosts cleared' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/user/reset
// @desc    จำลอง "เริ่มใหม่" ของบัญชีนี้ — ล้างประวัติ/เหรียญ/ไอเทม/upgrade ทิ้ง + reset สถิติบน User
//          (starter item อย่าง Camera/Fridge จะถูกสร้างกลับให้เองตอนเปิดหน้า Inventory ครั้งถัดไป)
router.post('/user/reset', async (req, res) => {
  try {
    await Promise.all([
      QuestHistory.deleteMany({ userId: req.userId }),
      Achievement.deleteMany({ userId: req.userId }),
      InventoryItem.deleteMany({ userId: req.userId }),
      UserUpgrade.deleteMany({ userId: req.userId }),
      User.updateOne(
        { _id: req.userId },
        {
          $set: {
            points: 0,
            xp: 0,
            level: 1,
            rank: 'Bronze',
            redEnergyExpiresAt: null,
            blueEnergyExpiresAt: null,
            greenEnergyExpiresAt: null,
          },
        }
      ),
    ]);
    res.json({ message: 'Account reset' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Quest
// ---------------------------------------------------------------------------

// @route   POST /api/admin/quests/:id/force-complete
// @desc    เหมือน POST /api/quests/:id/complete ทุกอย่างแต่ข้ามเงื่อนไขทั้งหมด (isDaily ทำไปแล้ว,
//          actionKey เช่น fridge_check, ไม่แคร์ quest.type) ใช้ได้แม้เป็น party quest
//          (ให้รางวัลบัญชีแอดมินเองเท่านั้น ไม่ fan-out ให้สมาชิกห้อง — ถ้าอยากทดสอบ fan-out จริง
//          ใช้ POST /api/admin/parties/:id/force-complete แทน)
router.post('/quests/:id/force-complete', async (req, res) => {
  try {
    const quest = await Quest.findById(req.params.id);
    if (!quest) {
      return res.status(404).json({ message: 'Quest not found' });
    }

    const user = await User.findById(req.userId).select('-avatarData');
    const bonuses = withEnergyBoosts(await getUserBonuses(user._id), user);
    const reward = applyBonuses(bonuses, quest);

    const history = await QuestHistory.create({
      userId: user._id,
      questId: quest._id,
      pointsEarned: reward.points,
      xpEarned: reward.rankXp,
    });

    user.points += reward.points;
    user.xp += reward.xp;
    user.level = progression.levelFromXp(user.xp);
    await user.save();

    const newAchievements = await syncAchievements(user._id);

    res.json({
      message: 'Quest force-completed',
      earned: { points: reward.points, xp: reward.xp },
      newAchievements,
      historyId: history._id,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/quests/reset-today
// @desc    เหมือน Super Energy แต่ฟรี — ล้างประวัติเควสวันนี้ทิ้งทั้งหมด
router.post('/quests/reset-today', async (req, res) => {
  try {
    const result = await QuestHistory.deleteMany({
      userId: req.userId,
      completedAt: { $gte: startOfToday() },
    });
    res.json({ questsReset: result.deletedCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/quests/reset-all
// @desc    ล้างประวัติเควสทั้งหมดตั้งแต่ต้น — ทดสอบ empty state ของหน้า History
router.post('/quests/reset-all', async (req, res) => {
  try {
    const result = await QuestHistory.deleteMany({ userId: req.userId });
    res.json({ questsReset: result.deletedCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Party
// ---------------------------------------------------------------------------

// @route   GET /api/admin/parties
// @desc    list ทุกห้องในระบบ (ไม่ใช่แค่ห้องตัวเอง) ไว้เลือกห้องมา force-complete ทดสอบ
router.get('/parties', async (req, res) => {
  try {
    const parties = await Party.find().sort({ createdAt: -1 }).limit(50).populate('questId', 'title type');
    const memberCounts = await PartyMember.aggregate([
      { $match: { partyId: { $in: parties.map((p) => p._id) } } },
      { $group: { _id: '$partyId', count: { $sum: 1 } } },
    ]);
    const countMap = new Map(memberCounts.map((c) => [String(c._id), c.count]));

    res.json({
      parties: parties.map((p) => ({
        id: p._id,
        name: p.name,
        questTitle: p.questId?.title ?? 'Unknown quest',
        status: p.status,
        memberCount: countMap.get(String(p._id)) || 0,
        eventDate: p.eventDate,
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/parties/:id/force-complete
// @desc    เหมือน POST /api/party/complete ทุกอย่าง (fan-out รางวัลให้สมาชิกทุกคนจริง) แต่ข้ามเช็ค
//          "ต้องเป็น leader" — ยังคง latch สถานะ open->completed กันกดซ้ำ
router.post('/parties/:id/force-complete', async (req, res) => {
  try {
    const party = await Party.findOneAndUpdate(
      { _id: req.params.id, status: 'open' },
      { status: 'completed', completedAt: new Date() },
      { new: true }
    ).populate('questId');

    if (!party) {
      return res.status(409).json({ message: 'Party not found or already completed' });
    }

    const quest = party.questId;
    if (!quest) {
      return res.status(409).json({ message: 'This quest no longer exists' });
    }

    const members = await PartyMember.find({ partyId: party._id });
    const startOfDay = startOfToday();
    let awardedCount = 0;

    for (const m of members) {
      const already = await QuestHistory.findOne({
        userId: m.userId,
        questId: quest._id,
        completedAt: { $gte: startOfDay },
      });
      if (already) continue;

      const user = await User.findById(m.userId).select('-avatarData');
      if (!user) continue;

      const bonuses = withEnergyBoosts(await getUserBonuses(user._id), user);
      const reward = applyBonuses(bonuses, quest);

      await QuestHistory.create({
        userId: user._id,
        questId: quest._id,
        pointsEarned: reward.points,
        xpEarned: reward.rankXp,
      });

      user.points += reward.points;
      user.xp += reward.xp;
      user.level = progression.levelFromXp(user.xp);
      await user.save();

      await syncAchievements(user._id);
      awardedCount += 1;
    }

    res.json({ message: 'Party force-completed', awardedCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Achievement
// ---------------------------------------------------------------------------

// @route   POST /api/admin/achievements/:medalType/unlock
// @desc    ปลดล็อกเหรียญไหนก็ได้ทันที ข้าม required count
router.post('/achievements/:medalType/unlock', async (req, res) => {
  try {
    const medal = MEDALS.find((m) => m.medalType === req.params.medalType);
    if (!medal) {
      return res.status(404).json({ message: 'Medal not found' });
    }

    await Achievement.findOneAndUpdate(
      { userId: req.userId, medalType: medal.medalType },
      { userId: req.userId, medalType: medal.medalType },
      { upsert: true, setDefaultsOnInsert: true }
    );
    res.json({ message: 'Medal unlocked', medalType: medal.medalType });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/achievements/reset
router.post('/achievements/reset', async (req, res) => {
  try {
    const result = await Achievement.deleteMany({ userId: req.userId });
    res.json({ removed: result.deletedCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

// @route   POST /api/admin/inventory/grant
// @desc    เพิ่มไอเทม (itemType ไหนก็ได้ใน ITEMS รวม camera/fridge/energy ทั้ง 4) ข้าม cost
router.post('/inventory/grant', async (req, res) => {
  try {
    const { itemType, quantity } = req.body;
    if (!ITEMS.some((i) => i.itemType === itemType) || typeof quantity !== 'number' || quantity < 1) {
      return res.status(400).json({ message: 'Invalid itemType or quantity' });
    }

    const item = await InventoryItem.findOneAndUpdate(
      { userId: req.userId, itemType },
      { $inc: { quantity }, $setOnInsert: { userId: req.userId, itemType } },
      { upsert: true, new: true }
    );
    res.json({ itemType, quantity: item.quantity });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/inventory/reset
router.post('/inventory/reset', async (req, res) => {
  try {
    const result = await InventoryItem.deleteMany({ userId: req.userId });
    res.json({ removed: result.deletedCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Upgrade
// ---------------------------------------------------------------------------

// @route   POST /api/admin/upgrades/set-level
router.post('/upgrades/set-level', async (req, res) => {
  try {
    const { upgradeType, level } = req.body;
    const upgrade = UPGRADES.find((u) => u.upgradeType === upgradeType);
    if (!upgrade || typeof level !== 'number' || level < 0 || level > upgrade.maxLevel) {
      return res.status(400).json({ message: 'Invalid upgradeType or level' });
    }

    const saved = await UserUpgrade.findOneAndUpdate(
      { userId: req.userId, upgradeType },
      { userId: req.userId, upgradeType, level },
      { upsert: true, new: true }
    );
    res.json({ upgradeType, level: saved.level });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Season
// ---------------------------------------------------------------------------

// @route   GET /api/admin/seasons
router.get('/seasons', async (req, res) => {
  try {
    const seasons = await Season.find().sort({ seasonNumber: -1 }).limit(20);
    res.json({ seasons });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/admin/seasons/expire-current
// @desc    ทำให้ season ที่ active อยู่หมดอายุทันที แล้วเรียก ensureActiveSeason() ต่อเลย ทดสอบ
//          path จริงของ auto-reseason (ไม่ได้ bypass logic การหมุน season)
router.post('/seasons/expire-current', async (req, res) => {
  try {
    await Season.updateOne({ isActive: true }, { $set: { endDate: new Date(Date.now() - 1000) } });
    const next = await ensureActiveSeason();
    res.json({ season: next });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Notification
// ---------------------------------------------------------------------------

const TEST_NOTIFICATIONS = {
  quest_complete: { title: 'Quest Completed', message: '[Admin Test] +10 points' },
  achievement: { title: 'Achievement Unlocked', message: '[Admin Test] Food Saver — Complete 10 food waste quests' },
  fridge_expiring: { title: 'Almost Expired', message: '[Admin Test] Test Item expires soon' },
};

// @route   POST /api/admin/notifications/test
router.post('/notifications/test', async (req, res) => {
  try {
    const { type } = req.body;
    const template = TEST_NOTIFICATIONS[type];
    if (!template) {
      return res.status(400).json({ message: 'Invalid notification type' });
    }

    await createNotification({
      userId: req.userId,
      type,
      title: template.title,
      message: template.message,
      // timestamp ใน dedupeKey กัน createNotification เมิน request ซ้ำ (idempotent ด้วย dedupeKey เดิม)
      // อยากยิงทดสอบซ้ำกี่ครั้งก็ได้ ไม่ใช่แค่ครั้งแรก
      dedupeKey: `admin-test:${type}:${Date.now()}`,
    });
    res.json({ message: 'Test notification sent' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// Fridge
// ---------------------------------------------------------------------------

// @route   POST /api/admin/fridge/add-test-item
// @desc    expiresInHours ติดลบได้ = จำลองของหมดอายุไปแล้ว ทดสอบ ensureExpiryNotifications
//          โดยไม่ต้องรอเวลาจริง
router.post('/fridge/add-test-item', async (req, res) => {
  try {
    const { itemName, expiresInHours } = req.body;
    if (!itemName || typeof expiresInHours !== 'number') {
      return res.status(400).json({ message: 'itemName and expiresInHours are required' });
    }

    const item = await FridgeItem.create({
      userId: req.userId,
      itemName,
      expirationDate: new Date(Date.now() + expiresInHours * 60 * 60 * 1000),
    });
    res.json({ item });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
