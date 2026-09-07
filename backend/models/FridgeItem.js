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
    // path ของรูปที่ผู้ใช้ถ่ายไว้
    // ⚠️ ตอนนี้เก็บเป็น path ในเครื่องของผู้ใช้เท่านั้น (ยังไม่ได้อัปโหลดรูปขึ้น server จริง)
    // แปลว่าถ้าเปลี่ยนเครื่อง/ลบแอพ รูปจะหาย เหลือแต่ชื่อกับวันหมดอายุ
    // TODO: ทำ upload รูปขึ้น server หรือ cloud storage แล้วเก็บเป็น URL แทน
    photoPath: {
      type: String,
      default: null,
    },
    addedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('FridgeItem', FridgeItemSchema);
