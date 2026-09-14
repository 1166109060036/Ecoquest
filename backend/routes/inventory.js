const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getInventory, buyItem, useItem } = require('../utils/inventory');

const router = express.Router();

// @route   GET /api/inventory
// @desc    ไอเทมทั้งหมดที่ user มี (แจกไอเทมตั้งต้นให้อัตโนมัติถ้ายังไม่มี) — ไอเทมที่ซื้อได้ยังไม่เคยซื้อ
//          ก็ส่งกลับมาด้วย (quantity: 0) ให้การ์ดร้านค้าฝั่งแอพใช้ข้อมูลชุดเดียวกันนี้ได้เลย
router.get('/', authMiddleware, async (req, res) => {
  try {
    const items = await getInventory(req.userId);
    res.json({ items });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/inventory/:itemType/buy
// @desc    ซื้อไอเทม 1 ชิ้นด้วย Points (ตอนนี้มีแค่ไอเทม Energy ที่ซื้อได้ ดู utils/inventory.js#ITEMS)
router.post('/:itemType/buy', authMiddleware, async (req, res) => {
  try {
    const result = await buyItem(req.userId, req.params.itemType);
    if (result.error) {
      return res.status(result.error.status).json({ message: result.error.message });
    }
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/inventory/:itemType/use
// @desc    ใช้ไอเทม 1 ชิ้น — หักจาก inventory แล้วใส่ผลทันที (บัฟชั่วคราว หรือรีเซ็ทเควสวันนี้)
router.post('/:itemType/use', authMiddleware, async (req, res) => {
  try {
    const result = await useItem(req.userId, req.params.itemType);
    if (result.error) {
      return res.status(result.error.status).json({ message: result.error.message });
    }
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
