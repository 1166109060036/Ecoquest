const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getInventory } = require('../utils/inventory');

const router = express.Router();

// @route   GET /api/inventory
// @desc    ไอเทมทั้งหมดที่ user มี (แจกไอเทมตั้งต้นให้อัตโนมัติถ้ายังไม่มี)
router.get('/', authMiddleware, async (req, res) => {
  try {
    const items = await getInventory(req.userId);
    res.json({ items });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
