const express = require('express');
const QuestHistory = require('../models/QuestHistory');
const QuestSubmission = require('../models/QuestSubmission');
const Quest = require('../models/Quest');
const authMiddleware = require('../middleware/auth');
const { co2AndPartiesPipeline } = require('../utils/profilePayload');
const { equivalentsFor } = require('../utils/impactEquivalents');

// ผลกระทบรวมของผู้เล่นทั้งเมือง (อาจารย์ให้ผู้ใช้รู้สึกว่าภารกิจช่วยโลกจริง 28 ก.ย. 2026) — การ์ด "Ebetsu's impact"
// บนสุดของแท็บ Feed ใน Community
// CO2 ใช้ pipeline เดียวกับโปรไฟล์ (utils/profilePayload.js) แต่รวมทุกคน — เพดานต่อวันยังคิดแยกต่อคน ยอดเมือง = ผลรวม
// โปรไฟล์ทุกคนพอดี / นับเฉพาะที่ได้รางวัลแล้ว (QuestHistory — แอดมินยึดแต้มคืน = แถวถูกลบ ไม่นับ)
// + ผลกระทบแบบนับชิ้นจากฟอร์มหลักฐาน (countedImpact) เช่น จำนวนภาชนะที่ส่งคืนร้าน
const router = express.Router();

// คำนวณหนักขึ้นตามจำนวนผู้เล่น — cache ในหน่วยความจำ 5 นาทีพอ (Render รันอินสแตนซ์เดียว)
const CACHE_MS = 5 * 60 * 1000;
let cache = null;

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

// ผลกระทบที่นับเป็นจำนวนชิ้น (8 ต.ค. 2026) — เควสที่มีฟอร์มให้กรอกจำนวน (Quest.proofForm.countLabel เช่น Return Containers
// "กี่ชิ้น") รวม details.count ของหลักฐานที่ผ่านทั้งเมือง จัดกลุ่มตาม Quest.impactCategory/impactMetric
// (เช่น "Containers Returned" / "items") — เควสใหม่ที่มีฟอร์มจำนวนขึ้นการ์ดเองโดยไม่ต้องแก้ตรงนี้
// ไม่นับที่แอดมินยึดแต้มคืน (status rejected) / โพสต์ที่ถอนรูปแต่แต้มอยู่ยังนับ (ทำจริงแล้ว)
const countedImpact = (since) =>
  QuestSubmission.aggregate([
    {
      $match: {
        status: 'approved',
        'details.count': { $gt: 0 },
        ...(since ? { createdAt: { $gte: since } } : {}),
      },
    },
    { $group: { _id: '$questId', total: { $sum: '$details.count' } } },
    { $lookup: { from: Quest.collection.name, localField: '_id', foreignField: '_id', as: 'quest' } },
    { $unwind: '$quest' },
    { $match: { 'quest.impactCategory': { $nin: [null, ''] } } },
    {
      $group: {
        _id: { label: '$quest.impactCategory', metric: '$quest.impactMetric' },
        total: { $sum: '$total' },
      },
    },
    { $sort: { total: -1 } },
    { $project: { _id: 0, label: '$_id.label', metric: '$_id.metric', total: 1 } },
  ]);

const summarize = async (since = null) => {
  const match = since ? { completedAt: { $gte: since } } : {};
  const [co2Agg, quests, players, counted] = await Promise.all([
    QuestHistory.aggregate(co2AndPartiesPipeline(match)),
    QuestHistory.countDocuments({ ...match, checkIn: { $ne: true } }),
    QuestHistory.distinct('userId', match),
    countedImpact(since),
  ]);
  const co2eKg = Math.round(((co2Agg[0] && co2Agg[0].co2eEstimateKg) || 0) * 1000) / 1000;
  return {
    co2eKg,
    questsCompleted: quests,
    players: players.length,
    equivalents: equivalentsFor(co2eKg),
    // [{ label: 'Containers Returned', metric: 'items', total: 37 }] — ว่าง = ยังไม่มีใครกรอก
    counted,
  };
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
