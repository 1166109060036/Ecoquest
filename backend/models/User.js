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
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', UserSchema);
