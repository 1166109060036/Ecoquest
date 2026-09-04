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
    energy: {
      type: Number,
      default: 5,
      min: 0,
      max: 5,
    },
    lastEnergyUpdate: {
      type: Date,
      default: Date.now,
      // ใช้คำนวณว่า energy ควร regen ไปแล้วกี่แต้ม
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', UserSchema);
