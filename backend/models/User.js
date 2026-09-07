const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      // ไม่ required เพราะ guest user จะไม่มี email
      unique: true,
      sparse: true, // อนุญาตให้หลาย document เป็น null ได้ (guest)
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      // ไม่ required สำหรับ guest
    },
    isGuest: {
      type: Boolean,
      default: false,
    },
    displayName: {
      type: String,
      default: 'Player',
    },

    // ---- ฟิลด์ระบบเกม ----
    level: {
      type: Number,
      default: 1,
    },
    xp: {
      type: Number,
      default: 0,
      // สะสมตลอด ไม่ reset
    },
    points: {
      type: Number,
      default: 0,
    },
    rank: {
      type: String,
      default: 'Bronze',
      // reset ทุก season
    },
    seasonId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Season',
      default: null,
    },
    // หมายเหตุ: เคยมีฟิลด์ energy / lastEnergyUpdate อยู่ตรงนี้
    // แต่ระบบ Energy ถูกตัดออกจากดีไซน์แล้ว (quest ทำได้โดยไม่เสียพลังงาน) จึงลบทิ้ง

    // ---- ฟิลด์สำหรับ flow ลืมรหัสผ่าน (OTP ทางอีเมล) ----
    // เก็บแค่ hash ของ OTP (เหมือน password) ไม่เก็บ OTP ตัวจริงไว้ในฐานข้อมูล
    resetOtpHash: { type: String, default: null },
    resetOtpExpires: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', UserSchema);
