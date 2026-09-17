const mongoose = require('mongoose');

// เควสที่ user กด Start แล้วแต่ยังไม่กด Complete — มีอยู่แค่ตอน "กำลังทำ" เท่านั้น
// พอกด Complete แถวนี้จะถูกลบทิ้งทันที (ดู routes/quests.js POST /:id/complete) ไม่เก็บ
// status: 'completed' ไว้ เพราะเควสที่ไม่ใช่รายวันต้องทำซ้ำได้อีกในวันเดียวกัน ถ้าเก็บแถว
// completed ค้างไว้จะไปติด unique index ด้านล่างทำให้ start ใหม่ไม่ได้เลย — ประวัติที่ทำสำเร็จ
// จริงๆ ดูที่ QuestHistory อยู่แล้ว ไม่ต้องซ้ำที่นี่
//
// ไม่มีฟิลด์ dayKey/หมดอายุ ตามที่ผู้ใช้ต้องการ — เควสที่ start ค้างไว้ไม่มีวันหมดอายุ ค้างจนกว่า
// จะกด Complete หรือ Cancel เอง
const QuestProgressSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    questId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Quest',
      required: true,
    },
    startedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// กด Start ซ้ำเควสเดิมไม่ได้ (และกันแข่งกันตอนกดรัวๆ พร้อมกัน — ดู upsert ที่ POST /:id/start)
QuestProgressSchema.index({ userId: 1, questId: 1 }, { unique: true });

module.exports = mongoose.model('QuestProgress', QuestProgressSchema);
