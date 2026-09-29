const express = require('express');
const mongoose = require('mongoose');
const QuestSubmission = require('../models/QuestSubmission');
const authMiddleware = require('../middleware/auth');
const { isAdminUser } = require('../middleware/admin');
const {
  APPROVALS_NEEDED,
  REJECTIONS_NEEDED,
  finalizeSubmission,
  sweepQuietly,
  toSubmissionPayload,
  PUBLIC_USER_FIELDS,
  QUEST_FIELDS,
} = require('../utils/submissions');

// ตรวจหลักฐานภารกิจของผู้เล่นคนอื่น (ระบบตรวจสอบภารกิจ 28 ก.ย. 2026 — กติกาดู utils/submissions.js)
// ⚠️ ใครก็ตรวจได้ (รวม guest) ยกเว้นเจ้าของหลักฐาน / สมาชิกห้องของปาร์ตี้นั้น — สร้าง guest หลายบัญชีมาอนุมัติ
// ตัวเองได้ในทางทฤษฎี แอดมินยังตัดสินทับได้เสมอ (ข้อจำกัดที่ตกลงไว้ บันทึกใน PROJECT_CONTEXT.md)
const router = express.Router();

// submission ที่คนนี้ตรวจได้: pending + ไม่ใช่ของตัวเอง + ไม่ใช่ห้องที่ตัวเองอยู่ + ยังไม่เคยโหวต
const reviewableFilter = (userId) => {
  const me = new mongoose.Types.ObjectId(String(userId));
  return {
    status: 'pending',
    userId: { $ne: me },
    memberIds: { $ne: me },
    approvals: { $ne: me },
    rejections: { $ne: me },
  };
};

// @route   GET /api/reviews/queue
// @desc    หลักฐานที่รอให้คนนี้ตรวจ (ใหม่สุดก่อน 20 อัน) + จำนวนทั้งหมดที่รอ (ให้แบนเนอร์ในฟีดโชว์)
router.get('/queue', authMiddleware, async (req, res) => {
  try {
    await sweepQuietly();
    const filter = reviewableFilter(req.userId);
    const [items, pendingCount, isAdmin] = await Promise.all([
      QuestSubmission.find(filter)
        .sort({ createdAt: -1 })
        .limit(20)
        .select('-photoData')
        .populate('userId', PUBLIC_USER_FIELDS)
        .populate('questId', QUEST_FIELDS),
      QuestSubmission.countDocuments(filter),
      isAdminUser(req.userId),
    ]);

    res.json({
      submissions: items.map((s) => toSubmissionPayload(s, req.userId)),
      pendingCount,
      // แอดมินโหวตครั้งเดียวตัดสินเลย — แอพโชว์ป้ายบอก
      isAdmin,
      approvalsNeeded: APPROVALS_NEEDED,
      rejectionsNeeded: REJECTIONS_NEEDED,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/reviews/:id/vote
// @desc    โหวตผ่าน/ไม่ผ่าน 1 ครั้งต่อคน — ครบเกณฑ์ (หรือเป็นแอดมิน) ตัดสินทันที
//          body: { approve: boolean }
router.post('/:id/vote', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid submission id' });
    }
    if (typeof req.body?.approve !== 'boolean') {
      return res.status(400).json({ message: 'Missing vote' });
    }
    const approve = req.body.approve;
    const me = String(req.userId);

    const submission = await QuestSubmission.findById(req.params.id).select('-photoData');
    if (!submission) return res.status(404).json({ message: 'Submission not found' });
    if (String(submission.userId) === me || submission.memberIds.some((id) => String(id) === me)) {
      return res.status(403).json({ message: "You can't review your own proof" });
    }
    if (submission.status !== 'pending') {
      return res.status(409).json({ message: 'This proof has already been reviewed' });
    }

    // บันทึกโหวตแบบมีเงื่อนไขใน query เดียว — กดซ้ำ/กดพร้อมกันสองเครื่องนับได้ครั้งเดียว
    const field = approve ? 'approvals' : 'rejections';
    const updated = await QuestSubmission.findOneAndUpdate(
      { _id: submission._id, ...reviewableFilter(req.userId) },
      { $addToSet: { [field]: new mongoose.Types.ObjectId(me) } },
      { new: true, projection: { photoData: 0 } }
    );
    if (!updated) {
      return res.status(409).json({ message: 'You have already reviewed this proof' });
    }

    // แอดมินตัดสินเลย / คนทั่วไปรอครบเกณฑ์
    let decision = null;
    let decidedBy = 'peers';
    if (await isAdminUser(req.userId)) {
      decision = approve ? 'approved' : 'rejected';
      decidedBy = 'admin';
    } else if (updated.approvals.length >= APPROVALS_NEEDED) {
      decision = 'approved';
    } else if (updated.rejections.length >= REJECTIONS_NEEDED) {
      decision = 'rejected';
    }

    let status = 'pending';
    if (decision) {
      const finalized = await finalizeSubmission(updated._id, decision, decidedBy);
      // null = มีคนอื่นตัดสินชิงไปก่อนพอดี (โหวตพร้อมกัน) — อ่านสถานะจริงกลับมาตอบ
      status = finalized
        ? finalized.status
        : (await QuestSubmission.findById(updated._id).select('status')).status;
    }

    res.json({
      message: status === 'pending' ? 'Vote recorded' : `Proof ${status}`,
      status,
      approvals: updated.approvals.length,
      rejections: updated.rejections.length,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
