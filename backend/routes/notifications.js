const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getNotifications, markAllRead } = require('../utils/notifications');
const { registerPushId, unregisterPushId } = require('../utils/push');

const router = express.Router();

const toClient = (n) => ({
  id: n._id,
  type: n.type,
  title: n.title,
  message: n.message,
  isRead: n.readAt != null,
  data: n.data ?? null,
  createdAt: n.createdAt,
});

// @route   GET /api/notifications
// @desc    แจ้งเตือนทั้งหมดของ user (ล่าสุดขึ้นก่อน) — สร้างแจ้งเตือนของใกล้หมดอายุให้อัตโนมัติก่อนดึง
router.get('/', authMiddleware, async (req, res) => {
  try {
    const notifications = await getNotifications(req.userId);
    res.json({ notifications: notifications.map(toClient) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/notifications/read
// @desc    มาร์กว่าอ่านแจ้งเตือนทั้งหมดแล้ว (เรียกตอนเข้าหน้า Notification)
router.post('/read', authMiddleware, async (req, res) => {
  try {
    await markAllRead(req.userId);
    res.json({ message: 'Marked as read' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/notifications/push-id
// @desc    จำ Firebase Installation ID (FID) ของเครื่องนี้ไว้ส่ง push (แอพเรียกทุกครั้งที่ FCM ลงทะเบียนเครื่อง) — ดู utils/push.js
router.post('/push-id', authMiddleware, async (req, res) => {
  const { fid } = req.body ?? {};
  if (typeof fid !== 'string' || fid.length < 10 || fid.length > 256) {
    return res.status(400).json({ message: 'Invalid push id' });
  }
  try {
    await registerPushId(req.userId, fid);
    res.json({ message: 'Push id saved' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE /api/notifications/push-id
// @desc    เลิกส่ง push เข้าเครื่องนี้ (เรียกตอน logout ก่อนลบ session)
router.delete('/push-id', authMiddleware, async (req, res) => {
  const { fid } = req.body ?? {};
  if (typeof fid !== 'string') {
    return res.status(400).json({ message: 'Invalid push id' });
  }
  try {
    await unregisterPushId(req.userId, fid);
    res.json({ message: 'Push id removed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
