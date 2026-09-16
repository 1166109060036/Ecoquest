const verifyToken = require('../utils/verifyToken');
const ChatMessage = require('../models/ChatMessage');
const User = require('../models/User');
const PartyMember = require('../models/PartyMember');
const Friendship = require('../models/Friendship');
const { pairKey } = require('../utils/friendKey');

// แผนที่ userId -> เซ็ตของ socketId ที่ user นั้นเปิดอยู่ตอนนี้ (คนเดียวเปิดแอพหลายเครื่อง/หลายแท็บ
// พร้อมกันได้ เลยเป็น Set ไม่ใช่ค่าเดียว) — เก็บใน memory ของโปรเซสนี้เฉยๆ
//
// ⚠️ ใช้ได้เพราะ Render free tier รันแค่ 1 instance เท่านั้น — ถ้าอนาคต scale ออกหลาย instance
// ต้องเปลี่ยนไปใช้ Redis adapter ของ socket.io (@socket.io/redis-adapter) แทน ไม่งั้น user ที่ต่อ
// อยู่กับ instance A จะไม่เห็นข้อความที่ broadcast จาก instance B
const onlineSockets = new Map();

const registerSocket = (userId, socketId) => {
  const key = String(userId);
  if (!onlineSockets.has(key)) onlineSockets.set(key, new Set());
  onlineSockets.get(key).add(socketId);
};

const unregisterSocket = (userId, socketId) => {
  const key = String(userId);
  const set = onlineSockets.get(key);
  if (!set) return;
  set.delete(socketId);
  if (set.size === 0) onlineSockets.delete(key);
};

// คืน array ของ socketId ทั้งหมดที่ user คนนี้เปิดอยู่ (ว่างถ้าไม่ได้ออนไลน์) — party.js เรียกใช้เพื่อ
// join/leave ห้องแชทปาร์ตี้ของ session ที่เปิดค้างอยู่แบบสด ไม่ต้องรอ reconnect ใหม่
const getSocketsForUser = (userId) => Array.from(onlineSockets.get(String(userId)) || []);

const partyRoom = (partyId) => `party:${partyId}`;

const toMessagePayload = (msg, fromUser) => ({
  id: msg._id,
  channelType: msg.channelType,
  channelId: msg.channelId,
  fromUserId: msg.fromUserId,
  fromDisplayName: fromUser ? fromUser.displayName : 'Player',
  text: msg.text,
  createdAt: msg.createdAt,
});

// เก็บ reference ของ io ไว้ใช้ตอน routes/party.js เรียก syncPartyRoomForUser (ไม่ส่ง io เข้าไปให้
// party.js ตรงๆ เพื่อไม่ให้ต้องรู้เรื่อง room/socket ภายใน — sockets module นี้ดูแลเองที่เดียว)
let ioInstance = null;

const initSocket = (io) => {
  ioInstance = io;
  // auth ตอน handshake ครั้งเดียว (ไม่ใช่ทุกข้อความ) — เช็ค JWT เดียวกับ authMiddleware ของ HTTP
  // ผ่าน verifyToken() ตัวกลาง (ดู utils/verifyToken.js — Phase 0 แยกออกมาให้ใช้ร่วมกันตรงนี้)
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth && socket.handshake.auth.token;
      if (!token) return next(new Error('unauthorized'));
      socket.userId = verifyToken(token);
      next();
    } catch (err) {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', async (socket) => {
    registerSocket(socket.userId, socket.id);
    // ทุกคนอยู่ห้องโลกเสมอ
    socket.join('world');

    // ถ้าอยู่ปาร์ตี้อยู่แล้วตอน connect (เช่น เปิดแอพใหม่/reconnect หลัง backend sleep) ก็ join ห้อง
    // แชทปาร์ตี้ให้ทันที ไม่ต้องรอ action อะไรก่อน — join/:partyId, start, complete, leave ใน
    // routes/party.js เป็นคนจัดการ join/leave ห้องนี้ต่อสำหรับ session ที่เปิดค้างอยู่ระหว่างทาง
    try {
      const membership = await PartyMember.findOne({ userId: socket.userId });
      if (membership) socket.join(partyRoom(membership.partyId));
    } catch (err) {
      console.error('เช็คห้องปาร์ตี้ตอน socket connect ไม่สำเร็จ:', err.message);
    }

    socket.on('chat:send', async (payload, ack) => {
      try {
        const channelType = payload && payload.channelType;
        const text = (payload && payload.text ? String(payload.text) : '').trim();

        if (!text) {
          if (ack) ack({ ok: false, message: 'Message cannot be empty' });
          return;
        }
        if (text.length > 1000) {
          if (ack) ack({ ok: false, message: 'Message is too long' });
          return;
        }

        if (channelType === 'world') {
          const message = await ChatMessage.create({
            channelType: 'world',
            channelId: 'world',
            fromUserId: socket.userId,
            text,
          });
          const fromUser = await User.findById(socket.userId).select('displayName');
          const outgoing = toMessagePayload(message, fromUser);
          io.to('world').emit('chat:message', outgoing);
          if (ack) ack({ ok: true, message: outgoing });
          return;
        }

        if (channelType === 'party') {
          // ไม่เชื่อ channelId ที่ client ส่งมาตรงๆ — หา partyId จริงจาก membership ของ socket.userId
          // เอง เสมอ (กันส่งข้อความเข้าห้องที่ตัวเองไม่ได้อยู่)
          const membership = await PartyMember.findOne({ userId: socket.userId });
          if (!membership) {
            if (ack) ack({ ok: false, message: 'You are not in a party' });
            return;
          }

          const message = await ChatMessage.create({
            channelType: 'party',
            channelId: membership.partyId.toString(),
            fromUserId: socket.userId,
            text,
          });
          const fromUser = await User.findById(socket.userId).select('displayName');
          const outgoing = toMessagePayload(message, fromUser);
          io.to(partyRoom(membership.partyId)).emit('chat:message', outgoing);
          if (ack) ack({ ok: true, message: outgoing });
          return;
        }

        if (channelType === 'friend') {
          const friendUserId = payload && payload.channelId;
          if (!friendUserId) {
            if (ack) ack({ ok: false, message: 'Missing friend id' });
            return;
          }

          // ต้องเป็นเพื่อนกัน (accepted) จริงถึงจะ DM กันได้ — เช็คจาก DB เสมอ ไม่เชื่อ client
          const key = pairKey(socket.userId, friendUserId);
          const friendship = await Friendship.findOne({ pairKey: key, status: 'accepted' });
          if (!friendship) {
            if (ack) ack({ ok: false, message: 'You are not friends with this player' });
            return;
          }

          const message = await ChatMessage.create({
            channelType: 'friend',
            channelId: key,
            fromUserId: socket.userId,
            text,
          });
          const fromUser = await User.findById(socket.userId).select('displayName');
          const outgoing = toMessagePayload(message, fromUser);

          // ไม่มีห้อง (room) แบบตายตัวสำหรับ DM — ส่งตรงไปที่ socket ของทั้งสองฝ่าย (รวมทุก session/
          // อุปกรณ์ของผู้ส่งเองด้วย ให้แท็บ/เครื่องอื่นที่เปิดอยู่เห็นข้อความตัวเองส่งไปด้วย)
          const targetSocketIds = [
            ...getSocketsForUser(socket.userId),
            ...getSocketsForUser(friendUserId),
          ];
          if (targetSocketIds.length > 0) {
            io.to(targetSocketIds).emit('chat:message', outgoing);
          }
          if (ack) ack({ ok: true, message: outgoing });
          return;
        }

        if (ack) ack({ ok: false, message: 'Unknown chat channel' });
      } catch (err) {
        console.error('ส่งข้อความแชทไม่สำเร็จ:', err.message);
        if (ack) ack({ ok: false, message: 'Failed to send message' });
      }
    });

    socket.on('disconnect', () => {
      unregisterSocket(socket.userId, socket.id);
    });
  });
};

// เรียกจาก routes/party.js ตอน join/leave ห้องปาร์ตี้จริง (เปลี่ยน PartyMember) เพื่อ join/leave
// ห้องแชทของ session ที่เปิดค้างอยู่แบบสด — ไม่ต้องรอ user reconnect ใหม่ถึงจะเห็นห้องที่เพิ่งเข้า/ออก
const syncPartyRoomForUser = (userId, partyId, action) => {
  if (!ioInstance) return;
  for (const socketId of getSocketsForUser(userId)) {
    const socket = ioInstance.sockets.sockets.get(socketId);
    if (!socket) continue;
    if (action === 'join') socket.join(partyRoom(partyId));
    else socket.leave(partyRoom(partyId));
  }
};

module.exports = { initSocket, getSocketsForUser, partyRoom, syncPartyRoomForUser };
