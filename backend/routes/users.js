const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');
const QuestHistory = require('../models/QuestHistory');
const authMiddleware = require('../middleware/auth');
const { buildProfileStats } = require('../utils/profilePayload');
const { getAchievements } = require('../utils/achievements');

const router = express.Router();

// @route   GET /api/users/:id
// @desc    ดูโปรไฟล์สาธารณะของผู้เล่นคนอื่น (เช่นกดจากรายชื่อสมาชิกในหน้า Party)
//          ผู้เล่นที่ login แล้วดูของกันและกันได้ทุกคน ไม่ต้องอยู่ห้องเดียวกัน
//
// ⚠️ endpoint แรกในระบบที่เปิดข้อมูลของ user คนหนึ่งให้อีกคนอ่าน — ต้องคัดฟิลด์แบบ
// allow-list เท่านั้น ห้ามใช้ .select('-password') เพราะยังหลุด email/resetOtpHash/
// resetOtpExpires ออกไปได้ และไม่ส่ง avatarPath เพราะเป็น path ในเครื่องของเจ้าของรูป
// เครื่องคนอื่นเปิดไม่ได้อยู่ดี (ดู backend/models/User.js)
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid user id' });
    }

    const user = await User.findById(req.params.id).select('displayName level xp points rank');
    if (!user) {
      return res.status(404).json({ message: 'Player not found' });
    }

    const [{ progress, stats }, medals, historyDocs] = await Promise.all([
      buildProfileStats(user),
      getAchievements(user._id),
      // ประวัติเควสล่าสุด — query + serialize แบบเดียวกับ GET /quests/history
      // ให้แอพใช้ model เดิมซ้ำได้เลย
      QuestHistory.find({ userId: user._id })
        .sort({ completedAt: -1 })
        .limit(20)
        .populate('questId', 'title category type'),
    ]);

    res.json({
      user: {
        id: user._id,
        displayName: user.displayName,
        level: progress.level,
        points: user.points,
        rank: progress.rankTier,
      },
      progress,
      stats,
      medals,
      history: historyDocs.map((h) => ({
        id: h._id,
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

module.exports = router;
