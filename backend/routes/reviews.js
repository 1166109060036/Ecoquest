const express = require('express');
const mongoose = require('mongoose');
const QuestSubmission = require('../models/QuestSubmission');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const { adminEmails } = require('../middleware/admin');
const {
  APPROVALS_NEEDED,
  REJECTIONS_NEEDED,
  escalationCutoff,
  finalizeSubmission,
  sweepQuietly,
  toSubmissionPayload,
  PUBLIC_USER_FIELDS,
  QUEST_FIELDS,
} = require('../utils/submissions');

// ตรวจหลักฐานภารกิจของผู้เล่นคนอื่น (ระบบตรวจสอบภารกิจ 28 ก.ย. 2026 — กติกาดู utils/submissions.js)
// ตรวจได้เฉพาะบัญชีจริง (guest ไม่ได้ — ผู้ใช้กำหนด 30 ก.ย. 2026 ไม่มีเลเวลขั้นต่ำ) ยกเว้นเจ้าของหลักฐาน / สมาชิกห้อง
// ของปาร์ตี้นั้น / ค้างเกิน 48 ชม. = แอดมินเท่านั้น
const router = express.Router();

// บทบาทของคนตรวจ — query ผู้ใช้ครั้งเดียวได้ทั้ง guest และแอดมิน (แอดมินต้องเป็นบัญชีจริงที่มี email อยู่แล้ว)
const reviewerRole = async (userId) => {
  const user = await User.findById(userId).select('email isGuest');
  if (!user) return { canReview: false, isAdmin: false };
  const isAdmin = Boolean(user.email) && adminEmails().includes(user.email.toLowerCase());
  return { canReview: isAdmin || !user.isGuest, isAdmin };
};

// submission ที่คนนี้ตรวจได้: pending + ไม่ใช่ของตัวเอง + ไม่ใช่ห้องที่ตัวเองอยู่ + ยังไม่เคยโหวต
// + ไม่ใช่แอดมิน = เฉพาะที่ยังไม่เกิน 48 ชม. (เกินแล้วรอแอดมิน)
const reviewableFilter = (userId, { isAdmin }) => {
  const me = new mongoose.Types.ObjectId(String(userId));
  return {
    status: 'pending',
    userId: { $ne: me },
    memberIds: { $ne: me },
    approvals: { $ne: me },
    rejections: { $ne: me },
    ...(isAdmin ? {} : { createdAt: { $gte: escalationCutoff() } }),
  };
};

const GUEST_REVIEW_MESSAGE = 'Create an account to help review quests';

// @route   GET /api/reviews/queue
// @desc    หลักฐานที่รอให้คนนี้ตรวจ 20 อัน + จำนวนทั้งหมดที่รอ (ให้แบนเนอร์ในฟีดโชว์)
//          ผู้เล่นทั่วไป: ใหม่สุดก่อน / แอดมิน: ที่ค้างเกิน 48 ชม. (รอแอดมิน) ขึ้นก่อน เก่าสุดก่อน แล้วค่อยของใหม่
//          guest: คิวว่าง + canReview: false (แอพชวนสมัครบัญชีแทน)
router.get('/queue', authMiddleware, async (req, res) => {
  try {
    await sweepQuietly();
    const role = await reviewerRole(req.userId);
    if (!role.canReview) {
      return res.json({
        submissions: [],
        pendingCount: 0,
        escalatedCount: 0,
        isAdmin: false,
        canReview: false,
        approvalsNeeded: APPROVALS_NEEDED,
        rejectionsNeeded: REJECTIONS_NEEDED,
      });
    }
    const filter = reviewableFilter(req.userId, role);
    const find = (extra, sort, limit) =>
      QuestSubmission.find({ ...filter, ...extra })
        .sort(sort)
        .limit(limit)
        .select('-photoData')
        .populate('userId', PUBLIC_USER_FIELDS)
        .populate('questId', QUEST_FIELDS);

    let items;
    let escalatedCount = 0;
    if (role.isAdmin) {
      const overdue = { createdAt: { $lt: escalationCutoff() } };
      const [escalated, count] = await Promise.all([
        find(overdue, { createdAt: 1 }, 20),
        QuestSubmission.countDocuments({ ...filter, ...overdue }),
      ]);
      escalatedCount = count;
      const fresh =
        escalated.length < 20
          ? await find({ createdAt: { $gte: escalationCutoff() } }, { createdAt: -1 }, 20 - escalated.length)
          : [];
      items = [...escalated, ...fresh];
    } else {
      items = await find({}, { createdAt: -1 }, 20);
    }
    const pendingCount = await QuestSubmission.countDocuments(filter);

    res.json({
      submissions: items.map((s) => toSubmissionPayload(s, req.userId)),
      pendingCount,
      escalatedCount,
      canReview: true,
      // แอดมินโหวตครั้งเดียวตัดสินเลย — แอพโชว์ป้ายบอก
      isAdmin: role.isAdmin,
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

    const role = await reviewerRole(req.userId);
    if (!role.canReview) return res.status(403).json({ message: GUEST_REVIEW_MESSAGE });

    const submission = await QuestSubmission.findById(req.params.id).select('-photoData');
    if (!submission) return res.status(404).json({ message: 'Submission not found' });
    if (String(submission.userId) === me || submission.memberIds.some((id) => String(id) === me)) {
      return res.status(403).json({ message: "You can't review your own proof" });
    }
    if (submission.status !== 'pending') {
      return res.status(409).json({ message: 'This proof has already been reviewed' });
    }
    if (!role.isAdmin && submission.createdAt < escalationCutoff()) {
      return res.status(409).json({ message: 'This proof is now waiting for an admin' });
    }

    // บันทึกโหวตแบบมีเงื่อนไขใน query เดียว — กดซ้ำ/กดพร้อมกันสองเครื่องนับได้ครั้งเดียว
    const field = approve ? 'approvals' : 'rejections';
    const updated = await QuestSubmission.findOneAndUpdate(
      { _id: submission._id, ...reviewableFilter(req.userId, role) },
      { $addToSet: { [field]: new mongoose.Types.ObjectId(me) } },
      { new: true, projection: { photoData: 0 } }
    );
    if (!updated) {
      return res.status(409).json({ message: 'You have already reviewed this proof' });
    }

    // แอดมินตัดสินเลย / คนทั่วไปรอครบเกณฑ์
    let decision = null;
    let decidedBy = 'peers';
    if (role.isAdmin) {
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
