const express = require('express');
const authMiddleware = require('../middleware/auth');
const { bingoPayload } = require('../utils/bingo');

// Eco Bingo รายสัปดาห์ (utils/bingo.js) — ให้รางวัลเองตอนเควสได้รางวัล (utils/questRewards.js) ไม่มีปุ่ม "รับรางวัล"
const router = express.Router();

// @route   GET /api/bingo
// @desc    การ์ดสัปดาห์นี้ (สร้างให้ถ้ายังไม่มี) + สถานะแต่ละช่อง (done / pending = ส่งหลักฐานแล้วรอตรวจ) + แถวที่ครบ
//          justClaimed = แถวที่เพิ่งให้รางวัลตอนเปิดหน้านี้ (เก็บตกกรณีรอบก่อนพัง ปกติเป็น null)
router.get('/', authMiddleware, async (req, res) => {
  try {
    res.json(await bingoPayload(req.userId));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
