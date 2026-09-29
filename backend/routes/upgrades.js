const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getUpgrades, buyUpgrade } = require('../utils/upgrades');
const {
  shopEnabled,
  upgradesEnabled,
  SHOP_ONLY_UPGRADES,
  UPGRADES_CLOSED_MESSAGE,
} = require('../utils/featureFlags');

// ร้านปิด = ซ่อน upgrade ที่ผูกกับร้าน (Quest Unlock) — ดู utils/featureFlags.js
const isHidden = (upgradeType) => !shopEnabled() && SHOP_ONLY_UPGRADES.includes(upgradeType);

const router = express.Router();

// @route   GET /api/upgrades
// @desc    upgrade ทั้งหมด + ระดับที่ user มี + ราคาระดับถัดไป
router.get('/', authMiddleware, async (req, res) => {
  try {
    const upgrades = upgradesEnabled()
      ? (await getUpgrades(req.userId)).filter((u) => !isHidden(u.upgradeType))
      : [];
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
    if (!upgradesEnabled() || isHidden(req.params.upgradeType)) {
      return res.status(403).json({ message: UPGRADES_CLOSED_MESSAGE });
    }
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
