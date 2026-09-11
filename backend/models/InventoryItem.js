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
      // เช่น 'camera', 'fridge' — นิยามของแต่ละ type อยู่ใน utils/inventory.js (ITEMS)
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

// กันไม่ให้ user ได้ไอเทม type เดิมซ้ำเป็นหลายแถว (ใช้คู่กับ findOneAndUpdate upsert ใน utils/inventory.js)
InventoryItemSchema.index({ userId: 1, itemType: 1 }, { unique: true });

module.exports = mongoose.model('InventoryItem', InventoryItemSchema);
