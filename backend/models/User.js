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
    // รูปโปรไฟล์ — เก็บไฟล์จริงเป็น Buffer ในเอกสารนี้เลย (ไม่ใช้ cloud storage แยก
    // เพื่อไม่ต้องพึ่ง service ภายนอก/credential เพิ่ม) เสิร์ฟผ่าน GET /users/:id/avatar
    // ไม่ query มาโดยไม่ตั้งใจ เพราะ query อื่นๆ ที่ query user ทั้งก้อนต้อง .select('-avatarData')
    // ไม่งั้นจะลาก Buffer รูปมาด้วยทุกครั้งทั้งที่ไม่ได้ใช้ (ดูตัวอย่างที่ routes/auth.js, routes/users.js)
    avatarData: {
      type: Buffer,
      default: null,
    },
    avatarContentType: {
      type: String, // 'image/jpeg' หรือ 'image/png' เท่านั้น — เช็คที่ routes/auth.js ตอนอัปโหลด
      default: null,
    },
    // ใช้ทำ cache-busting query string (?v=) ตอนสร้าง avatarUrl ให้แอพ ไม่งั้นเปลี่ยนรูปแล้ว
    // แอพจะยังโชว์รูปเก่าที่ cache ไว้ตาม URL เดิม (ดู utils/avatar.js)
    avatarUpdatedAt: {
      type: Date,
      default: null,
    },
    // ปิดสวิตช์นี้ = ไม่สร้างแจ้งเตือนใหม่ให้คนนี้เลย (เควสสำเร็จ/เหรียญปลดล็อก/ของใกล้หมดอายุ)
    // เช็คที่ backend/utils/notifications.js#createNotification จุดเดียว ไม่ต้องเช็คซ้ำทุกจุดที่เรียกแจ้งเตือน
    notificationsEnabled: {
      type: Boolean,
      default: true,
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
    // หมายเหตุ: เคยมีฟิลด์ energy / lastEnergyUpdate อยู่ตรงนี้ (ระบบ stamina ที่ใช้แล้วหมดต้องรอเติม
    // ก่อนทำเควสได้อีก) แต่ถูกตัดออกจากดีไซน์แล้ว (quest ทำได้โดยไม่เสียพลังงาน) จึงลบทิ้ง
    //
    // 3 ฟิลด์ข้างล่างนี้เป็นคนละเรื่องกัน: เวลาหมดอายุของบัฟชั่วคราวจากไอเทม Energy ใน Inventory
    // (Red/Blue/Green Energy — ดู utils/inventory.js) เช็คแค่ "expiresAt > ตอนนี้ไหม" ไม่ใช่ stamina gate
    redEnergyExpiresAt: { type: Date, default: null },
    blueEnergyExpiresAt: { type: Date, default: null },
    greenEnergyExpiresAt: { type: Date, default: null },

    // ---- ฟิลด์สำหรับ flow ลืมรหัสผ่าน (OTP ทางอีเมล) ----
    // เก็บแค่ hash ของ OTP (เหมือน password) ไม่เก็บ OTP ตัวจริงไว้ในฐานข้อมูล
    resetOtpHash: { type: String, default: null },
    resetOtpExpires: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', UserSchema);
