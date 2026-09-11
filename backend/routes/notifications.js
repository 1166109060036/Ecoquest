const express = require('express');
const authMiddleware = require('../middleware/auth');
const { getNotifications, markAllRead } = require('../utils/notifications');

const router = express.Router();

const toClient = (n) => ({
  id: n._id,
  type: n.type,
  title: n.title,
  message: n.message,
  isRead: n.readAt != null,
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

module.exports = router;
