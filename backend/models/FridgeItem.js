const mongoose = require('mongoose');

// สำหรับ Mini Quest "Check Your Food & Expiration Dates"
const FridgeItemSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    itemName: {
      type: String,
      required: true,
    },
    expirationDate: {
      type: Date,
      required: true,
    },
    // จำนวนที่มีอยู่ — แสดงเป็น badge "xN" ในหน้า Fridge เหมือนไอเทมในหน้า Inventory
    quantity: {
      type: Number,
      default: 1,
      min: 1,
    },
    addedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('FridgeItem', FridgeItemSchema);
