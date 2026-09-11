const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getUpgrades, buyUpgrade } = require('../utils/upgrades');

const router = express.Router();

// @route   GET /api/upgrades
// @desc    upgrade ทั้งหมด + ระดับที่ user มี + ราคาระดับถัดไป
router.get('/', authMiddleware, async (req, res) => {
  try {
    const upgrades = await getUpgrades(req.userId);
    res.json({ upgrades });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/upgrades/:upgradeType/buy
// @desc    ซื้อ upgrade 1 ระดับ — หักแต้มแบบ atomic กันแต้มติดลบและกดซื้อซ้อนกัน
router.post('/:upgradeType/buy', authMiddleware, async (req, res) => {
  try {
    const result = await buyUpgrade(req.userId, req.params.upgradeType);
    if (result.error) {
      return res.status(result.error.status).json({ message: result.error.message });
    }
    res.json({ upgrade: result.upgrade, points: result.points });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
