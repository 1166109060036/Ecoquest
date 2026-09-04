const mongoose = require('mongoose');

// บันทึกทุกครั้งที่ user ทำ quest สำเร็จ — แยก collection ต่างหากเพื่อให้ query/scale ง่าย
const QuestHistorySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    questId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Quest',
      required: true,
    },
    completedAt: {
      type: Date,
      default: Date.now,
    },
    pointsEarned: {
      type: Number,
      required: true,
    },
    xpEarned: {
      type: Number,
      required: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('QuestHistory', QuestHistorySchema);
