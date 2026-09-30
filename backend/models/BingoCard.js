const mongoose = require('mongoose');

// การ์ด Eco Bingo รายสัปดาห์ของผู้ใช้ 1 คน (utils/bingo.js) — 3x3 ช่องกลาง (index 4) ฟรี อีก 8 ช่องเป็นเควส solo
// เก็บลงฐานข้อมูลแทนการคำนวณใหม่ทุกครั้ง: ถ้าเควสถูกเปิด/ปิดระหว่างสัปดาห์ การ์ดจะไม่สลับช่องต่อหน้าผู้เล่น
// ช่องที่ทำแล้วไม่ได้เก็บตรงนี้ — คิดจาก QuestHistory ของสัปดาห์นั้นทุกครั้ง (แหล่งความจริงเดียวกับรางวัล)
// เก็บแค่ "แถวที่รับรางวัลไปแล้ว" กันให้รางวัลซ้ำ
const BingoCardSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    // วันจันทร์ของสัปดาห์ (YYYY-MM-DD เวลาญี่ปุ่น — utils/questDay.js#weekKeyFor)
    weekKey: { type: String, required: true },
    // 9 ช่องเรียงซ้ายไปขวา บนลงล่าง — null = ช่องฟรี (ช่องกลาง / เควสไม่พอ)
    cells: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Quest', default: null }],
    // index ของแถว (utils/bingo.js#LINES) ที่ได้รางวัลไปแล้ว
    claimedLines: { type: [Number], default: [] },
    // ครบทั้งการ์ดแล้วได้โบนัสไปแล้วหรือยัง
    fullClaimed: { type: Boolean, default: false },
  },
  { timestamps: true }
);

BingoCardSchema.index({ userId: 1, weekKey: 1 }, { unique: true });

module.exports = mongoose.model('BingoCard', BingoCardSchema);
