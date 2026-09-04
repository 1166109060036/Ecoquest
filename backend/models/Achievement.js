const mongoose = require('mongoose');

// Medal ที่ user ปลดล็อกแล้ว เช่น Food Saver, Recycling, Community, Plastic Reduction
const AchievementSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    medalType: {
      type: String,
      required: true,
      // เช่น 'food_saver', 'recycling', 'community', 'plastic_reduction'
    },
    unlockedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// กันไม่ให้ user ปลดล็อก medal ซ้ำอันเดิม
AchievementSchema.index({ userId: 1, medalType: 1 }, { unique: true });

module.exports = mongoose.model('Achievement', AchievementSchema);
