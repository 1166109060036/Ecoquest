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
    // ⚠️ ฟิลด์เก่า — path รูปในเครื่องของผู้ใช้เอง (ก่อนมี photoData) เก็บไว้เฉยๆ เพื่อของเก่าที่มีอยู่
    // แล้วใน production ยัง fallback โชว์รูปได้บนเครื่องที่ถ่ายไว้ ของใหม่ทุกชิ้นไม่ใช้ฟิลด์นี้อีกแล้ว
    // (ดู photoData ด้านล่าง) ห้ามลบทิ้ง ไม่งั้นของเก่าที่มีแต่ photoPath จะเสียรูปที่เคยเห็นได้ไปเปล่าๆ
    photoPath: {
      type: String,
      default: null,
    },
    // รูปจริงที่อัปโหลดขึ้น server แล้ว — เก็บเป็น Buffer ตรงในเอกสารนี้เลย (แนวเดียวกับ
    // User.avatarData) ไม่ใช้ cloud storage ภายนอกเพราะ Render free tier filesystem เป็น ephemeral
    // เสิร์ฟกลับผ่าน GET /api/fridge-items/:id/photo (public เหมือน GET /api/users/:id/avatar)
    photoData: {
      type: Buffer,
      default: null,
    },
    photoContentType: {
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
