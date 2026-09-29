const express = require('express');
const QuestHistory = require('../models/QuestHistory');
const authMiddleware = require('../middleware/auth');
const { co2AndPartiesPipeline } = require('../utils/profilePayload');
const { equivalentsFor } = require('../utils/impactEquivalents');

// ผลกระทบรวมของผู้เล่นทั้งเมือง (อาจารย์ให้ผู้ใช้รู้สึกว่าภารกิจช่วยโลกจริง 28 ก.ย. 2026) — การ์ด "Ebetsu's impact"
// บนสุดของแท็บ Feed ใน Community
// CO2 ใช้ pipeline เดียวกับโปรไฟล์ (utils/profilePayload.js) แต่รวมทุกคน — เพดานต่อวันยังคิดแยกต่อคน ยอดเมือง = ผลรวม
// โปรไฟล์ทุกคนพอดี / นับเฉพาะที่ได้รางวัลแล้ว (QuestHistory เกิดตอนหลักฐานผ่านการตรวจ ไม่นับที่รอตรวจ)
const router = express.Router();

// คำนวณหนักขึ้นตามจำนวนผู้เล่น — cache ในหน่วยความจำ 5 นาทีพอ (Render รันอินสแตนซ์เดียว)
const CACHE_MS = 5 * 60 * 1000;
let cache = null;

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

const summarize = async (since = null) => {
  const match = since ? { completedAt: { $gte: since } } : {};
  const [co2Agg, quests, players] = await Promise.all([
    QuestHistory.aggregate(co2AndPartiesPipeline(match)),
    QuestHistory.countDocuments({ ...match, checkIn: { $ne: true } }),
    QuestHistory.distinct('userId', match),
  ]);
  const co2eKg = Math.round(((co2Agg[0] && co2Agg[0].co2eEstimateKg) || 0) * 1000) / 1000;
  return { co2eKg, questsCompleted: quests, players: players.length, equivalents: equivalentsFor(co2eKg) };
};

// @route   GET /api/impact/summary
// @desc    ยอดรวมทั้งเมือง ตลอดกาล + 7 วันล่าสุด
router.get('/summary', authMiddleware, async (req, res) => {
  try {
    if (!cache || Date.now() - cache.at > CACHE_MS) {
      const [allTime, thisWeek] = await Promise.all([
        summarize(),
        summarize(new Date(Date.now() - WEEK_MS)),
      ]);
      cache = { at: Date.now(), data: { allTime, thisWeek, city: 'Ebetsu' } };
    }
    res.json(cache.data);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
