const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getAchievements } = require('../utils/achievements');

const router = express.Router();

// @route   GET /api/achievements
// @desc    เหรียญทั้งหมด + สถานะว่าปลดล็อกหรือยัง + ความคืบหน้าของอันที่ยังไม่ปลดล็อก
// ส่งมาทั้งที่ปลดล็อกแล้วและยังไม่ปลดล็อก เพื่อให้ผู้เล่นเห็นว่าเหลืออีกกี่ครั้งถึงจะได้
router.get('/', authMiddleware, async (req, res) => {
  try {
    const achievements = await getAchievements(req.userId);
    res.json({ achievements });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
