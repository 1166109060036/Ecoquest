const express = require('express');
const ChatMessage = require('../models/ChatMessage');
const User = require('../models/User');
const PartyMember = require('../models/PartyMember');
const Friendship = require('../models/Friendship');
const authMiddleware = require('../middleware/auth');
const { pairKey } = require('../utils/friendKey');

const router = express.Router();

// แปลง ChatMessage เอกสาร (ยังไม่ populate fromUserId) ให้เป็นรูปที่แอพใช้ได้เลย
// รับ map ของ userId -> displayName มาด้วย กันต้อง query User ทีละข้อความ
const toMessagePayload = (msg, displayNameById) => ({
  id: msg._id,
  channelType: msg.channelType,
  channelId: msg.channelId,
  fromUserId: msg.fromUserId,
  fromDisplayName: displayNameById.get(String(msg.fromUserId)) || 'Player',
  text: msg.text,
  createdAt: msg.createdAt,
});

// ดึงประวัติของ channel หนึ่ง — ใช้ร่วมกันทั้ง world/party/friend (ต่างกันแค่ query filter)
// เรียงใหม่ล่าสุดก่อน (createdAt: -1) แล้ว reverse กลับให้แอพได้ลิสต์เรียงเก่า -> ใหม่ (โชว์ในแชทได้ตรงๆ)
const fetchHistory = async (filter, { before, limit }) => {
  const query = { ...filter };
  if (before) query.createdAt = { $lt: new Date(before) };

  const messages = await ChatMessage.find(query)
    .sort({ createdAt: -1 })
    .limit(Math.min(Number(limit) || 30, 100));

  const userIds = [...new Set(messages.map((m) => String(m.fromUserId)))];
  const users = await User.find({ _id: { $in: userIds } }).select('displayName');
  const displayNameById = new Map(users.map((u) => [String(u._id), u.displayName]));

  return messages.reverse().map((m) => toMessagePayload(m, displayNameById));
};

// @route   GET /api/chat/world/messages?before=&limit=
router.get('/world/messages', authMiddleware, async (req, res) => {
  try {
    const messages = await fetchHistory(
      { channelType: 'world', channelId: 'world' },
      req.query
    );
    res.json({ messages });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/chat/party/messages?before=&limit=
// @desc    ประวัติแชทของห้องปาร์ตี้ที่ req.userId อยู่ตอนนี้ — หา partyId จาก membership จริงเสมอ
//          ไม่รับ partyId จาก client (กันอ่านห้องที่ตัวเองไม่ได้อยู่)
router.get('/party/messages', authMiddleware, async (req, res) => {
  try {
    const membership = await PartyMember.findOne({ userId: req.userId });
    if (!membership) {
      return res.status(400).json({ message: 'You are not in a party' });
    }

    const messages = await fetchHistory(
      { channelType: 'party', channelId: membership.partyId.toString() },
      req.query
    );
    res.json({ messages });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/chat/friend/:friendUserId/messages?before=&limit=
// @desc    ประวัติ DM กับเพื่อนคนนี้ — ต้องเป็นเพื่อนกัน (accepted) จริงก่อนเสมอ
router.get('/friend/:friendUserId/messages', authMiddleware, async (req, res) => {
  try {
    const key = pairKey(req.userId, req.params.friendUserId);
    const friendship = await Friendship.findOne({ pairKey: key, status: 'accepted' });
    if (!friendship) {
      return res.status(403).json({ message: 'You are not friends with this player' });
    }

    const messages = await fetchHistory({ channelType: 'friend', channelId: key }, req.query);
    res.json({ messages });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
