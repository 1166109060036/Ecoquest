const mongoose = require('mongoose');

// คนที่เข้าร่วม party quest (อีเวนต์กลุ่ม) หนึ่งอีเวนต์
//
// ดีไซน์: "ปาร์ตี้" = กลุ่มคนที่เข้าร่วม party quest อันเดียวกัน ไม่ได้แยกเป็น collection ปาร์ตี้ต่างหาก
// ทำแบบนี้เพราะอีเวนต์กับปาร์ตี้เป็นสิ่งเดียวกันในดีไซน์นี้ (เข้าร่วม cleanup = อยู่ปาร์ตี้ cleanup)
// ถ้าอนาคตอยากให้หลายปาร์ตี้ลงอีเวนต์เดียวกันได้ ค่อยเพิ่ม partyId เข้ามาทีหลัง
const PartyMemberSchema = new mongoose.Schema(
  {
    questId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Quest',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // คนแรกที่เข้าร่วมอีเวนต์จะได้เป็นหัวหน้าปาร์ตี้โดยอัตโนมัติ
    // (ตอนนี้อีเวนต์มาจากการ seed ยังไม่มีระบบให้ผู้เล่นสร้างเอง — พอทำแล้วค่อยให้คนสร้างเป็นหัวหน้าแทน)
    isLeader: {
      type: Boolean,
      default: false,
    },
    joinedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// กันเข้าร่วมอีเวนต์เดิมซ้ำ
PartyMemberSchema.index({ questId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('PartyMember', PartyMemberSchema);
