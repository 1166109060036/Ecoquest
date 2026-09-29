const express = require('express');
const mongoose = require('mongoose');
const QuestSubmission = require('../models/QuestSubmission');
const authMiddleware = require('../middleware/auth');
const { toSubmissionPayload, QUEST_FIELDS } = require('../utils/submissions');

// หลักฐานภารกิจของตัวเอง + เสิร์ฟรูปหลักฐาน (ระบบตรวจสอบภารกิจ — ดู utils/submissions.js)
const router = express.Router();

// @route   GET /api/submissions/mine?status=pending
// @desc    หลักฐานที่ตัวเองส่งไป (หน้า Progress โชว์ "Waiting for review") — ไม่ใส่ status = ทุกสถานะ 30 อันล่าสุด
//          ปาร์ตี้ที่ตัวเองเป็นสมาชิก (แต่ไม่ใช่คนส่ง) ก็นับด้วย ให้สมาชิกเห็นว่ารูปกลุ่มกำลังรอตรวจ
router.get('/mine', authMiddleware, async (req, res) => {
  try {
    const me = new mongoose.Types.ObjectId(String(req.userId));
    const filter = { $or: [{ userId: me }, { memberIds: me }] };
    if (['pending', 'approved', 'rejected'].includes(req.query.status)) filter.status = req.query.status;

    const items = await QuestSubmission.find(filter)
      .sort({ createdAt: -1 })
      .limit(30)
      .select('-photoData')
      .populate('questId', QUEST_FIELDS);

    res.json({ submissions: items.map((s) => toSubmissionPayload(s, req.userId)) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/submissions/:id/photo
// @desc    เสิร์ฟรูปหลักฐาน — public ไม่ต้อง login (แนวเดียวกับรูปโปรไฟล์/รูปในตู้เย็น) เพราะ Image.network ฝั่งแอพ
//          ไม่ได้แนบ token และรูปหลักฐานที่ผ่านแล้วโชว์ในฟีดชุมชนให้ทุกคนเห็นอยู่แล้ว
router.get('/:id/photo', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid submission id' });
    }
    const submission = await QuestSubmission.findById(req.params.id).select('photoData photoContentType');
    if (!submission) return res.status(404).json({ message: 'Photo not found' });

    res.set('Content-Type', submission.photoContentType);
    // รูปของ submission ไม่เคยเปลี่ยน — cache ได้ตลอด
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    res.send(submission.photoData);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
