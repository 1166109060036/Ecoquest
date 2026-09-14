const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');
const QuestHistory = require('../models/QuestHistory');
const authMiddleware = require('../middleware/auth');
const { buildProfileStats } = require('../utils/profilePayload');
const { getAchievements } = require('../utils/achievements');
const { avatarUrlFor } = require('../utils/avatar');

const router = express.Router();

// @route   GET /api/users/:id
// @desc    ดูโปรไฟล์สาธารณะของผู้เล่นคนอื่น (เช่นกดจากรายชื่อสมาชิกในหน้า Party)
//          ผู้เล่นที่ login แล้วดูของกันและกันได้ทุกคน ไม่ต้องอยู่ห้องเดียวกัน
//
// ⚠️ endpoint แรกในระบบที่เปิดข้อมูลของ user คนหนึ่งให้อีกคนอ่าน — ต้องคัดฟิลด์แบบ
// allow-list เท่านั้น ห้ามใช้ .select('-password') เพราะยังหลุด email/resetOtpHash/
// resetOtpExpires ออกไปได้ — เอา avatarContentType/avatarUpdatedAt มาแค่สร้าง avatarUrl
// (ไม่เอา avatarData ตัวจริงมาด้วย หนักเกินไปสำหรับ route ที่ query กันบ่อยๆ)
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid user id' });
    }

    const user = await User.findById(req.params.id).select(
      'displayName level xp points rank avatarContentType avatarUpdatedAt'
    );
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
        avatarUrl: avatarUrlFor(user),
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

// @route   GET /api/users/:id/avatar
// @desc    ไฟล์รูปโปรไฟล์จริง (ไม่ใช่ JSON) — url นี้เอามาจาก avatarUrl ที่ route อื่นส่งให้แล้ว
//
// ⚠️ จงใจไม่ใส่ authMiddleware ตรงนี้ (ต่างจากทุก route อื่นในระบบ) เพราะ Image.network
// ฝั่งแอพจะโหลดรูปตรงๆ จาก URL โดยไม่ผ่าน service/provider ที่แนบ token ให้อัตโนมัติ
// การแนบ Authorization header ทำได้แต่เพิ่มความซับซ้อนเกินจำเป็นสำหรับรูปโปรไฟล์ซึ่งไม่ใช่
// ข้อมูลอ่อนไหว (เดารูปได้ก็แค่เห็นรูปโปรไฟล์ ไม่ใช่ข้อมูลส่วนตัวอื่น) — ต้องรู้ userId
// (ObjectId 24 ตัวอักษร) ถึงจะเดา URL ถูก เดารัวๆ ไม่ได้ประโยชน์อะไร
router.get('/:id/avatar', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).end();
    }

    const user = await User.findById(req.params.id).select('avatarData avatarContentType');
    if (!user || !user.avatarData) {
      return res.status(404).end();
    }

    // cache ฝั่ง client ได้เลยเพราะ URL มี ?v= กันรูปเก่าค้างอยู่แล้ว (ดู utils/avatar.js)
    res.set('Content-Type', user.avatarContentType);
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    res.send(user.avatarData);
  } catch (err) {
    console.error(err);
    res.status(500).end();
  }
});

module.exports = router;
