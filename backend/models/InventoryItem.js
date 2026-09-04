const mongoose = require('mongoose');

// Item ที่ user เก็บไว้ใช้ เช่น "energy_drink" (คูณคะแนน quest x2)
const InventoryItemSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    itemType: {
      type: String,
      required: true,
      // เช่น 'energy_drink' — เพิ่ม type ใหม่ได้เรื่อยๆ ตามฟีเจอร์ที่เพิ่ม
    },
    quantity: {
      type: Number,
      default: 1,
      min: 0,
    },
    acquiredAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('InventoryItem', InventoryItemSchema);
