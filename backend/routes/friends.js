const express = require('express');
const mongoose = require('mongoose');
const Friendship = require('../models/Friendship');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const { avatarUrlFor } = require('../utils/avatar');
const { pairKey } = require('../utils/friendKey');
const { notifyFriendRequest, notifyFriendAccepted } = require('../utils/notifications');

const router = express.Router();

// allow-list เดียวกับ GET /api/users/:id — ห้ามใช้ .select('-password') เพราะยังหลุด
// email/resetOtpHash/resetOtpExpires ออกไปได้ (ดูคอมเมนต์เต็มๆ ใน routes/users.js)
const PUBLIC_FIELDS = 'displayName level rank avatarContentType avatarUpdatedAt';

const toPublicUser = (user) => ({
  id: user._id,
  displayName: user.displayName,
  level: user.level,
  rank: user.rank,
  avatarUrl: avatarUrlFor(user),
});

// @route   GET /api/friends/search?q=
// @desc    ค้นหาผู้เล่นด้วย displayName (ไม่ unique — อาจเจอหลายคนชื่อเดียวกัน ผู้ใช้ต้องดูเลเวล/
//          รูปช่วยแยกเอง) แนบสถานะความสัมพันธ์ปัจจุบันไปด้วยให้ UI โชว์ปุ่มถูกต้อง (Add/Pending/Friends)
router.get('/search', authMiddleware, async (req, res) => {
  try {
    const q = (req.query.q || '').toString().trim();
    if (!q) return res.json({ results: [] });

    // escape ตัวอักษรพิเศษของ regex กัน user พิมพ์ค่าที่ทำให้ query พัง/ช้าผิดปกติ
    const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const users = await User.find({
      displayName: { $regex: escaped, $options: 'i' },
      _id: { $ne: req.userId },
    })
      .select(PUBLIC_FIELDS)
      .limit(20);

    if (users.length === 0) return res.json({ results: [] });

    const userIds = users.map((u) => u._id);
    const friendships = await Friendship.find({
      $or: [
        { requesterId: req.userId, recipientId: { $in: userIds } },
        { recipientId: req.userId, requesterId: { $in: userIds } },
      ],
    });

    // แม็พ otherUserId -> สถานะความสัมพันธ์กับ req.userId
    const statusByUserId = new Map();
    for (const f of friendships) {
      const otherId =
        f.requesterId.toString() === String(req.userId)
          ? f.recipientId.toString()
          : f.requesterId.toString();
      if (f.status === 'accepted') {
        statusByUserId.set(otherId, 'friends');
      } else {
        statusByUserId.set(
          otherId,
          f.requesterId.toString() === String(req.userId) ? 'pending_outgoing' : 'pending_incoming'
        );
      }
    }

    res.json({
      results: users.map((u) => ({
        ...toPublicUser(u),
        relationship: statusByUserId.get(u._id.toString()) || 'none',
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/friends/requests
// @desc    ส่งคำขอเพื่อน — ถ้าอีกฝ่ายส่งคำขอมาก่อนแล้ว (pending อยู่) auto-accept ให้เลยแทนตอบ error
//          (กันเคส 2 คนกดขอเพื่อนกันพร้อมกันพอดี ไม่ต้องให้ทั้งคู่ต้องกด accept กันไปมา)
router.post('/requests', authMiddleware, async (req, res) => {
  try {
    const { recipientId } = req.body;
    if (!recipientId || !mongoose.Types.ObjectId.isValid(recipientId)) {
      return res.status(400).json({ message: 'Invalid recipient' });
    }
    if (String(recipientId) === String(req.userId)) {
      return res.status(400).json({ message: 'You cannot add yourself as a friend' });
    }

    const recipient = await User.findById(recipientId).select(PUBLIC_FIELDS);
    if (!recipient) return res.status(404).json({ message: 'Player not found' });

    const key = pairKey(req.userId, recipientId);

    let friendship;
    try {
      friendship = await Friendship.create({
        requesterId: req.userId,
        recipientId,
        pairKey: key,
      });
    } catch (err) {
      if (err.code !== 11000) throw err;

      // ชน unique index — มีแถวคู่นี้อยู่แล้ว (อาจเป็นคำขอเก่าของเราเอง หรือคำขอย้อนกลับที่อีกฝ่ายส่งมา)
      const existing = await Friendship.findOne({ pairKey: key });
      if (!existing) throw err; // ไม่ควรเกิด แต่กันพลาด

      if (existing.status === 'accepted') {
        return res.status(409).json({ message: 'You are already friends' });
      }
      if (existing.requesterId.toString() === String(req.userId)) {
        return res.status(409).json({ message: 'Friend request already sent' });
      }

      // เป็นคำขอย้อนกลับที่ยัง pending — auto-accept แทน error
      existing.status = 'accepted';
      existing.respondedAt = new Date();
      await existing.save();

      const requester = await User.findById(req.userId).select(PUBLIC_FIELDS);
      try {
        await notifyFriendAccepted(existing.requesterId, requester, existing._id);
      } catch (notifyErr) {
        console.error('สร้างแจ้งเตือนรับคำขอเพื่อน (auto-accept) ไม่สำเร็จ:', notifyErr.message);
      }

      return res.json({ message: 'Friend request accepted', status: 'accepted' });
    }

    try {
      const requester = await User.findById(req.userId).select(PUBLIC_FIELDS);
      await notifyFriendRequest(recipientId, requester, friendship._id);
    } catch (notifyErr) {
      console.error('สร้างแจ้งเตือนคำขอเพื่อนไม่สำเร็จ:', notifyErr.message);
    }

    res.status(201).json({ message: 'Friend request sent', status: 'pending' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/friends/requests?direction=incoming|outgoing
router.get('/requests', authMiddleware, async (req, res) => {
  try {
    const direction = req.query.direction === 'outgoing' ? 'outgoing' : 'incoming';
    const filter =
      direction === 'incoming'
        ? { recipientId: req.userId, status: 'pending' }
        : { requesterId: req.userId, status: 'pending' };

    const requests = await Friendship.find(filter)
      .sort({ createdAt: -1 })
      .populate(direction === 'incoming' ? 'requesterId' : 'recipientId', PUBLIC_FIELDS);

    res.json({
      requests: requests
        .filter((r) => (direction === 'incoming' ? r.requesterId : r.recipientId))
        .map((r) => ({
          id: r._id,
          user: toPublicUser(direction === 'incoming' ? r.requesterId : r.recipientId),
          createdAt: r.createdAt,
        })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/friends/requests/:id/accept
router.post('/requests/:id/accept', authMiddleware, async (req, res) => {
  try {
    // atomic CAS แบบเดียวกับ party.js's /start และ /complete — กันกดซ้อน/กดหลัง cancel ไปแล้ว
    const friendship = await Friendship.findOneAndUpdate(
      { _id: req.params.id, recipientId: req.userId, status: 'pending' },
      { status: 'accepted', respondedAt: new Date() },
      { new: true }
    );

    if (!friendship) {
      return res.status(409).json({ message: 'This request is no longer pending' });
    }

    const accepter = await User.findById(req.userId).select(PUBLIC_FIELDS);
    try {
      await notifyFriendAccepted(friendship.requesterId, accepter, friendship._id);
    } catch (notifyErr) {
      console.error('สร้างแจ้งเตือนรับคำขอเพื่อนไม่สำเร็จ:', notifyErr.message);
    }

    res.json({ message: 'Friend request accepted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/friends/requests/:id/reject
// @desc    ผู้รับปฏิเสธคำขอ — ลบทิ้งเลย ไม่เก็บ log (อีกฝ่ายส่งคำขอใหม่ได้อีกทีหลัง)
router.post('/requests/:id/reject', authMiddleware, async (req, res) => {
  try {
    const { deletedCount } = await Friendship.deleteOne({
      _id: req.params.id,
      recipientId: req.userId,
      status: 'pending',
    });
    if (deletedCount === 0) {
      return res.status(409).json({ message: 'This request is no longer pending' });
    }
    res.json({ message: 'Friend request rejected' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/friends/requests/:id/cancel
// @desc    ผู้ส่งยกเลิกคำขอของตัวเองก่อนอีกฝ่ายตอบ
router.post('/requests/:id/cancel', authMiddleware, async (req, res) => {
  try {
    const { deletedCount } = await Friendship.deleteOne({
      _id: req.params.id,
      requesterId: req.userId,
      status: 'pending',
    });
    if (deletedCount === 0) {
      return res.status(409).json({ message: 'This request is no longer pending' });
    }
    res.json({ message: 'Friend request cancelled' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/friends
// @desc    ลิสต์เพื่อนที่ accepted แล้วทั้งหมด
router.get('/', authMiddleware, async (req, res) => {
  try {
    const friendships = await Friendship.find({
      status: 'accepted',
      $or: [{ requesterId: req.userId }, { recipientId: req.userId }],
    })
      .sort({ respondedAt: -1 })
      .populate('requesterId', PUBLIC_FIELDS)
      .populate('recipientId', PUBLIC_FIELDS);

    const friends = friendships
      .map((f) => {
        const isRequester = f.requesterId._id.toString() === String(req.userId);
        const other = isRequester ? f.recipientId : f.requesterId;
        return other ? { ...toPublicUser(other), friendSince: f.respondedAt } : null;
      })
      .filter(Boolean);

    res.json({ friends });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE /api/friends/:friendUserId
router.delete('/:friendUserId', authMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.friendUserId)) {
      return res.status(400).json({ message: 'Invalid user id' });
    }
    const key = pairKey(req.userId, req.params.friendUserId);
    const { deletedCount } = await Friendship.deleteOne({ pairKey: key, status: 'accepted' });
    if (deletedCount === 0) {
      return res.status(404).json({ message: 'You are not friends with this player' });
    }
    res.json({ message: 'Friend removed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
