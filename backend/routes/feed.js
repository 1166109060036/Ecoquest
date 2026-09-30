const express = require('express');
const mongoose = require('mongoose');
const QuestSubmission = require('../models/QuestSubmission');
const authMiddleware = require('../middleware/auth');
const { startOfToday } = require('../utils/questDay');
const {
  sweepQuietly,
  toSubmissionPayload,
  PUBLIC_USER_FIELDS,
  QUEST_FIELDS,
} = require('../utils/submissions');

// ฟีดกิจกรรมชุมชน (อาจารย์ให้คนอื่นเห็นข้อมูลภารกิจ 28 ก.ย. 2026) — หลักฐานภารกิจที่ผ่านการตรวจแล้วของทุกคน
// ใหม่สุดก่อน + ปุ่ม cheer — แท็บ Feed ใน Community (lib/pages/community/feed_tab.dart)
// ใช้ QuestSubmission ตัวเดียวกับระบบตรวจ (ไม่มี collection ฟีดแยก) — เห็นเฉพาะ approved
// Today Feed (30 ก.ย. 2026): เห็นแค่ที่ผ่านการตรวจวันนี้ (decidedAt >= เที่ยงคืนเวลาญี่ปุ่น) — ขึ้นวันใหม่รูปของเมื่อวาน
// ถูกลบทิ้ง (utils/submissions.js#purgeExpiredPhotos) ฟีดเลยต้องไม่โชว์โพสต์ที่ไม่มีรูปแล้ว
const router = express.Router();

// @route   GET /api/feed?before=<ISO date>&limit=20
// @desc    หน้าถัดไปใช้ submittedAt ของอันสุดท้ายเป็น before (cursor ตามเวลา ไม่ใช้ skip กันซ้ำตอนมีของใหม่แทรก)
router.get('/', authMiddleware, async (req, res) => {
  try {
    await sweepQuietly();
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);
    const filter = { status: 'approved', decidedAt: { $gte: startOfToday() } };
    const before = req.query.before ? new Date(req.query.before) : null;
    if (before && !Number.isNaN(before.getTime())) filter.createdAt = { $lt: before };

    const items = await QuestSubmission.find(filter)
      .sort({ createdAt: -1 })
      .limit(limit)
      .select('-photoData')
      .populate('userId', PUBLIC_USER_FIELDS)
      .populate('questId', QUEST_FIELDS);

    res.json({
      // บัญชีผู้ส่งถูกลบไปแล้ว (populate ได้ null) ไม่โชว์ในฟีด
      items: items.filter((s) => s.userId).map((s) => toSubmissionPayload(s, req.userId)),
      hasMore: items.length === limit,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/feed/:id/cheer
// @desc    กด/เลิกกด cheer (toggle) — 1 คน 1 ครั้งต่อโพสต์ กดให้ของตัวเองได้ไม่ได้ห้าม (แค่กำลังใจ ไม่มีผลกับแต้ม)
router.post('/:id/cheer', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid post id' });
    }
    const me = new mongoose.Types.ObjectId(String(req.userId));
    // ลองเพิ่มก่อน (ยังไม่เคยกด) — ไม่เจอแปลว่ากดไปแล้ว ให้เอาออกแทน ทั้งสองทางเป็น atomic query เดียว
    let post = await QuestSubmission.findOneAndUpdate(
      { _id: req.params.id, status: 'approved', cheers: { $ne: me } },
      { $addToSet: { cheers: me } },
      { new: true, projection: { cheers: 1 } }
    );
    let cheered = true;
    if (!post) {
      post = await QuestSubmission.findOneAndUpdate(
        { _id: req.params.id, status: 'approved', cheers: me },
        { $pull: { cheers: me } },
        { new: true, projection: { cheers: 1 } }
      );
      cheered = false;
    }
    if (!post) return res.status(404).json({ message: 'Post not found' });

    res.json({ cheers: post.cheers.length, cheeredByMe: cheered });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
