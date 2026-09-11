const mongoose = require('mongoose');

// Upgrade ที่ user ซื้อไปแล้ว (ซื้อซ้ำเพื่ออัพระดับได้) เช่น 'point_booster' ระดับ 3
// นิยามของแต่ละ upgrade + สูตรราคา/ผลของมัน อยู่ใน utils/upgrades.js (UPGRADES)
const UserUpgradeSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    upgradeType: {
      type: String,
      required: true,
      // เช่น 'point_booster', 'quest_unlock' — ห้ามเปลี่ยนค่าพวกนี้หลังมีคนซื้อไปแล้ว
    },
    level: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  { timestamps: true }
);

// กันไม่ให้ user มี upgrade ตัวเดียวกันหลายแถว (ใช้คู่กับ findOneAndUpdate upsert ใน utils/upgrades.js)
UserUpgradeSchema.index({ userId: 1, upgradeType: 1 }, { unique: true });

module.exports = mongoose.model('UserUpgrade', UserUpgradeSchema);
