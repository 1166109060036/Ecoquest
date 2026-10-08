const express = require('express');
const mongoose = require('mongoose');
const QuestSubmission = require('../models/QuestSubmission');
const authMiddleware = require('../middleware/auth');
const { isAdminUser } = require('../middleware/admin');
const {
  REPORTS_TO_HIDE,
  revokeSubmission,
  sweepQuietly,
  toSubmissionPayload,
  PUBLIC_USER_FIELDS,
  QUEST_FIELDS,
} = require('../utils/submissions');
const { notifyPostRemoved } = require('../utils/notifications');
const Quest = require('../models/Quest');

// โพสต์ที่ถูกรายงาน — แอดมินเท่านั้น (7 ต.ค. 2026 เลิกคิวให้ผู้เล่นตรวจทุกอัน ส่งรูปแล้วผ่านทันที ดู utils/submissions.js)
// แอดมินดูแค่โพสต์ที่ผู้เล่นรายงานมา (routes/feed.js POST /:id/report) แล้วเลือก:
//   keep   = รูปไม่มีปัญหา -> กลับมาโชว์ในฟีด (ถ้าถูกซ่อน) รายงานใหม่หลังจากนี้ไม่เปิดเรื่องซ้ำ
//   remove = ถอนรูปออก (เช่น มีข้อมูลส่วนตัว) แต่แต้มยังอยู่ — ทำเควสจริงแล้ว
//   revoke = รูปไม่ได้แสดงว่าทำเควสจริง -> ถอนรูป + ยึดแต้ม/XP/CO2 คืน
// path ยังเป็น /api/reviews (แอพเรียกที่เดิม) แม้ไม่มีการโหวตตรวจแล้ว
const router = express.Router();

const ACTIONS = ['keep', 'remove', 'revoke'];

// สรุปเหตุผลที่ถูกรายงาน { not_done: 2, personal_info: 1 } ให้แอดมินเห็นภาพรวม
const reasonCounts = (reports) =>
  (reports || []).reduce((acc, r) => {
    acc[r.reason] = (acc[r.reason] || 0) + 1;
    return acc;
  }, {});

// @route   GET /api/reviews/queue
// @desc    โพสต์ที่ถูกรายงานรอแอดมินดู (เก่าสุดก่อน) 20 อัน + จำนวนทั้งหมด (แบนเนอร์ในฟีดของแอดมิน)
//          ผู้เล่นทั่วไป: ว่างเสมอ + isAdmin: false (แอพไม่โชว์แบนเนอร์)
router.get('/queue', authMiddleware, async (req, res) => {
  try {
    await sweepQuietly();
    const isAdmin = await isAdminUser(req.userId);
    if (!isAdmin) {
      return res.json({ submissions: [], pendingCount: 0, isAdmin: false, reportsToHide: REPORTS_TO_HIDE });
    }
    const filter = { reportStatus: 'open', status: 'approved' };
    const [items, pendingCount] = await Promise.all([
      QuestSubmission.find(filter)
        .sort({ updatedAt: 1 })
        .limit(20)
        .select('-photoData')
        .populate('userId', PUBLIC_USER_FIELDS)
        .populate('questId', QUEST_FIELDS),
      QuestSubmission.countDocuments(filter),
    ]);
    res.json({
      submissions: items.map((s) => ({
        ...toSubmissionPayload(s, req.userId),
        reportCount: (s.reports || []).length,
        reportReasons: reasonCounts(s.reports),
        hiddenByReports: Boolean(s.hiddenByReports),
        // ของเก่าก่อน 7 ต.ค. 2026 ไม่มีบันทึกว่าให้แต้มใครไปเท่าไหร่ = ยึดคืนไม่ได้ (แค่ถอนรูป)
        canRevoke: (s.awards || []).length > 0,
      })),
      pendingCount,
      isAdmin: true,
      reportsToHide: REPORTS_TO_HIDE,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/reviews/:id/resolve
// @desc    แอดมินตัดสินโพสต์ที่ถูกรายงาน — body: { action: 'keep' | 'remove' | 'revoke' }
router.post('/:id/resolve', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid post id' });
    }
    const action = req.body && req.body.action;
    if (!ACTIONS.includes(action)) {
      return res.status(400).json({ message: 'Unknown action' });
    }
    if (!(await isAdminUser(req.userId))) {
      return res.status(403).json({ message: 'Only an admin can resolve reports' });
    }

    // ล็อกสถานะแบบ compare-and-swap (open -> ผลตัดสิน) — แอดมินกดซ้ำ/กดสองเครื่องพร้อมกันทำได้ครั้งเดียว
    const nextStatus = { keep: 'kept', remove: 'removed', revoke: 'revoked' }[action];
    const update =
      action === 'keep'
        ? { $set: { reportStatus: 'kept', hiddenByReports: false } }
        : action === 'remove'
          ? {
              $set: {
                reportStatus: 'removed',
                hiddenByReports: false,
                removedFromFeed: true,
                removedAt: new Date(),
                removedBy: req.userId,
              },
              $unset: { photoData: 1 },
            }
          : { $set: { reportStatus: 'revoked' } };
    const post = await QuestSubmission.findOneAndUpdate(
      { _id: req.params.id, reportStatus: 'open', status: 'approved' },
      update,
      { new: true, projection: { photoData: 0 } }
    );
    if (!post) {
      return res.status(409).json({ message: 'This report has already been handled' });
    }

    if (action === 'revoke') {
      await revokeSubmission(post, req.userId);
    } else if (action === 'remove') {
      try {
        const quest = await Quest.findById(post.questId).select('title');
        await notifyPostRemoved(post.userId, quest, post._id);
      } catch (notifyErr) {
        console.error('สร้างแจ้งเตือนถอนโพสต์ไม่สำเร็จ:', notifyErr.message);
      }
    }
    res.json({ message: 'Report resolved', reportStatus: nextStatus });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
