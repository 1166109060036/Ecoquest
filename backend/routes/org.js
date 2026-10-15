// บัญชีองค์กร + อีเวนต์องค์กร (14 ต.ค. 2026)
// องค์กร (NPO/บริษัท/โรงเรียน/หน่วยงานท้องถิ่น) ใช้แอพเป็นตัวกลางหาคนมาร่วมกิจกรรมสิ่งแวดล้อม:
//   1. ผู้ใช้ที่มีอีเมลสมัครเป็นองค์กร -> แอดมินอนุมัติ (User.organization)
//   2. องค์กรสร้างอีเวนต์ (models/OrgEvent.js) ตั้งแต้ม 10–40 P เอง
//   3. ผู้เล่นลงทะเบียน -> มางานจริงแล้วสแกน QR ที่องค์กรเปิด (utils/orgQr.js) -> ได้แต้มทันทีผ่าน awardQuest
// กันโกง: QR เปลี่ยนทุก 30 วิ, สแกนได้เฉพาะช่วงงาน (±30 นาที), 1 ครั้งต่อคนต่องาน, องค์กรสแกนงานตัวเองไม่ได้,
// งานยาวไม่เกิน 8 ชม., ไม่เกิน 3 งานต่อวันต่อองค์กร, แอดมินปิดองค์กรได้ (อีเวนต์ที่ยังไม่จัดถูกยกเลิก)
const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');
const Quest = require('../models/Quest');
const OrgEvent = require('../models/OrgEvent');
const OrgEventRegistration = require('../models/OrgEventRegistration');
const authMiddleware = require('../middleware/auth');
const { adminMiddleware, adminEmails } = require('../middleware/admin');
const { awardQuest } = require('../utils/questRewards');
const { qrFor, parseQr } = require('../utils/orgQr');
const { limitBy, byUser } = require('../utils/rateLimit');
const { avatarUrlFor } = require('../utils/avatar');
const { startOfDayFor } = require('../utils/questDay');
const {
  createNotification,
  notifyQuestCompleted,
  notifyOrgStatus,
  notifyOrgEventCancelled,
} = require('../utils/notifications');

const { ORG_TYPES } = User;
const router = express.Router();

// ---- กติกา ----
const ORG_POINTS_MIN = 10; // เควสปาร์ตี้เดิมได้ 20–30 P — ให้องค์กรตั้งได้กว้างกว่านิดหน่อย
const ORG_POINTS_MAX = 40;
const CHECKIN_EARLY_MS = 30 * 60 * 1000; // สแกนได้ก่อนงานเริ่ม 30 นาที
const CHECKIN_LATE_MS = 30 * 60 * 1000; // และหลังงานจบ 30 นาที
const MIN_DURATION_MS = 15 * 60 * 1000;
const MAX_DURATION_MS = 8 * 60 * 60 * 1000;
const MAX_DAYS_AHEAD = 60;
const MAX_EVENTS_PER_DAY = 3;
const MAX_CAPACITY = 1000;
const CATEGORIES = ['food_waste', 'recycling', 'plastic', 'community', 'energy'];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const limitApply = limitBy('org-apply', { windowMs: 60 * 60 * 1000, max: 5 }, byUser,
  'Too many requests. Please try again later');
const limitEdit = limitBy('org-edit', { windowMs: 60 * 60 * 1000, max: 20 }, byUser,
  'Too many requests. Please try again later');
const limitCreate = limitBy('org-create', { windowMs: 60 * 60 * 1000, max: 20 }, byUser,
  'You are creating events very quickly. Please try again later');
const limitCheckIn = limitBy('org-checkin', { windowMs: 15 * 60 * 1000, max: 30 }, byUser,
  'Too many scans. Please wait a moment and try again');

// รับเฉพาะ string — ค่าแปลกๆ (object/array/number) กลายเป็น '' ไม่ทำให้ .trim() พังเป็น 500
const str = (v) => (typeof v === 'string' ? v.trim() : '');
const toInt = (v) => (typeof v === 'number' && Number.isInteger(v) ? v : typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : NaN);
const toDate = (v) => {
  if (typeof v !== 'string' && typeof v !== 'number') return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

const orgPayload = (user) => {
  const o = user.organization || {};
  return {
    status: o.status || 'none',
    name: o.name || '',
    orgType: o.orgType || '',
    description: o.description || '',
    contactEmail: o.contactEmail || '',
    requestedAt: o.requestedAt || null,
    decidedAt: o.decidedAt || null,
    decisionNote: o.decisionNote || '',
  };
};

const ORG_USER_FIELDS = 'organization displayName avatarContentType avatarUpdatedAt';

// upcoming / live / ended / cancelled — คิดจากเวลาทุกครั้ง ไม่เก็บลง DB (ไม่มี scheduler)
const phaseOf = (event, now = Date.now()) => {
  if (event.status === 'cancelled') return 'cancelled';
  if (now < event.startAt.getTime()) return 'upcoming';
  if (now < event.endAt.getTime()) return 'live';
  return 'ended';
};
const checkInOpen = (event, now = Date.now()) =>
  event.status === 'scheduled'
  && now >= event.startAt.getTime() - CHECKIN_EARLY_MS
  && now <= event.endAt.getTime() + CHECKIN_LATE_MS;

// นับคนลงทะเบียน/เช็คอินของหลายอีเวนต์ใน query เดียว -> Map<eventId, {registered, attended}>
const countsFor = async (eventIds) => {
  const rows = await OrgEventRegistration.aggregate([
    { $match: { eventId: { $in: eventIds } } },
    { $group: { _id: { e: '$eventId', s: '$status' }, n: { $sum: 1 } } },
  ]);
  const map = new Map();
  for (const r of rows) {
    const k = String(r._id.e);
    const c = map.get(k) || { registered: 0, attended: 0 };
    c[r._id.s] = r.n;
    map.set(k, c);
  }
  return map;
};

// แปลงอีเวนต์หลายอันให้อยู่ในรูปที่แอพโชว์ได้เลย (ดึงองค์กร/จำนวน/สถานะของฉันแบบ batch)
const toEventPayloads = async (events, userId) => {
  if (events.length === 0) return [];
  const ids = events.map((e) => e._id);
  const [counts, orgs, mine] = await Promise.all([
    countsFor(ids),
    User.find({ _id: { $in: [...new Set(events.map((e) => String(e.orgUserId)))] } }).select(ORG_USER_FIELDS),
    OrgEventRegistration.find({ eventId: { $in: ids }, userId }).select('eventId status pointsEarned xpEarned'),
  ]);
  const orgById = new Map(orgs.map((u) => [String(u._id), u]));
  const mineById = new Map(mine.map((r) => [String(r.eventId), r]));
  const now = Date.now();

  return events.map((e) => {
    const c = counts.get(String(e._id)) || { registered: 0, attended: 0 };
    const org = orgById.get(String(e.orgUserId));
    const reg = mineById.get(String(e._id));
    const isMine = String(e.orgUserId) === String(userId);
    return {
      id: e._id,
      title: e.title,
      description: e.description,
      category: e.category,
      location: e.location,
      startAt: e.startAt,
      endAt: e.endAt,
      capacity: e.capacity,
      // จำนวนคนที่มีที่นั่งแล้ว = ลงทะเบียน + เช็คอินแล้ว
      joinedCount: c.registered + c.attended,
      attendedCount: c.attended,
      points: e.points,
      xp: e.points,
      phase: phaseOf(e, now),
      checkInOpen: checkInOpen(e, now),
      org: org
        ? { id: org._id, name: org.organization?.name || org.displayName, orgType: org.organization?.orgType || '', avatarUrl: avatarUrlFor(org) }
        : null,
      isMine,
      myStatus: reg ? reg.status : null,
      myReward: reg && reg.status === 'attended' ? { points: reg.pointsEarned, xp: reg.xpEarned } : null,
    };
  });
};
const toEventPayload = async (event, userId) => (await toEventPayloads([event], userId))[0];

const findEvent = async (id) => (mongoose.isValidObjectId(id) ? OrgEvent.findById(id) : null);

// ยกเลิกอีเวนต์ + ปิดเควสเงา + แจ้งทุกคนที่ลงทะเบียนไว้ — ใช้ทั้งตอนองค์กรยกเลิกเองและแอดมินปิดองค์กร
// CAS ที่ status: scheduled กันยกเลิกซ้ำ/แจ้งเตือนซ้ำ
const cancelEvent = async (eventId) => {
  const event = await OrgEvent.findOneAndUpdate(
    { _id: eventId, status: 'scheduled' },
    { status: 'cancelled', cancelledAt: new Date() },
    { new: true }
  );
  if (!event) return null;
  await Quest.updateOne({ _id: event.questId }, { isActive: false });
  const regs = await OrgEventRegistration.find({ eventId: event._id }).select('userId');
  for (const r of regs) {
    try {
      await notifyOrgEventCancelled(r.userId, event);
    } catch (err) {
      console.error('แจ้งยกเลิกอีเวนต์ไม่สำเร็จ:', err.message);
    }
  }
  return event;
};

// ---------------------------------------------------------------------------
// บัญชีองค์กร
// ---------------------------------------------------------------------------

// @route   GET /api/org/me
// @desc    สถานะองค์กรของฉัน + สมัครได้ไหม (guest ไม่มีอีเมล สมัครไม่ได้)
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('email isGuest organization');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({ organization: orgPayload(user), canApply: !user.isGuest && Boolean(user.email), email: user.email || '' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ตรวจข้อมูลองค์กร (ใช้ทั้งตอนสมัครและตอนแก้ไข) — คืน { error } หรือ { fields }
const readOrgFields = (body, fallbackEmail) => {
  const name = str(body?.name);
  const orgType = str(body?.orgType);
  const description = str(body?.description);
  const contactEmail = str(body?.contactEmail).toLowerCase() || fallbackEmail;
  if (name.length < 2 || name.length > 60) return { error: 'Organization name must be 2–60 characters' };
  if (!ORG_TYPES.includes(orgType)) return { error: 'Choose an organization type' };
  if (description.length < 10 || description.length > 500) {
    return { error: 'Tell us about your organization (10–500 characters)' };
  }
  if (!contactEmail || contactEmail.length > 120 || !EMAIL_RE.test(contactEmail)) {
    return { error: 'Enter a valid contact email' };
  }
  return { fields: { name, orgType, description, contactEmail } };
};

// @route   POST /api/org/apply
// @desc    สมัครเป็นองค์กร (สถานะ none/rejected เท่านั้น) — body: { name, orgType, description, contactEmail }
router.post('/apply', authMiddleware, limitApply, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('email isGuest organization displayName');
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.isGuest || !user.email) {
      return res.status(403).json({ message: 'Create an account with email before registering an organization' });
    }
    const status = user.organization?.status || 'none';
    if (status === 'pending') return res.status(409).json({ message: 'Your request is already waiting for approval' });
    if (status === 'approved') return res.status(409).json({ message: 'Your organization is already approved' });
    if (status === 'suspended') return res.status(403).json({ message: 'Your organization was suspended. Please contact the EcoQuest team' });

    const { error, fields } = readOrgFields(req.body, user.email);
    if (error) return res.status(400).json({ message: error });
    const { name, orgType, description, contactEmail } = fields;

    const requestedAt = new Date();
    // CAS ที่สถานะเดิม กันกดส่งซ้อนกัน 2 ครั้ง
    const updated = await User.findOneAndUpdate(
      { _id: user._id, 'organization.status': { $in: [status, ...(status === 'none' ? [null] : [])] } },
      {
        $set: {
          organization: {
            status: 'pending', name, orgType, description, contactEmail,
            requestedAt, decidedAt: null, decisionNote: '',
          },
        },
      },
      { new: true, projection: { organization: 1 } }
    );
    if (!updated) return res.status(409).json({ message: 'Your request is already waiting for approval' });

    // แจ้งแอดมินทุกคน (ไม่ต้องคอยเปิดหน้าอนุมัติเช็คเอง)
    try {
      const emails = adminEmails();
      if (emails.length) {
        const admins = await User.find({ email: { $in: emails } }).select('_id');
        for (const a of admins) {
          await createNotification({
            userId: a._id,
            type: 'org_status',
            title: 'New Organization Request',
            message: `${name} · open Settings → Admin Tools → Organizations to review it.`,
            dedupeKey: `org_request:${user._id}:${requestedAt.getTime()}`,
          });
        }
      }
    } catch (err) {
      console.error('แจ้งแอดมินคำขอองค์กรไม่สำเร็จ:', err.message);
    }

    res.status(201).json({ message: 'Request sent', organization: orgPayload(updated) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   PUT /api/org/me
// @desc    องค์กรที่อนุมัติแล้วแก้ชื่อ/ประเภท/คำอธิบาย/อีเมลติดต่อได้ (15 ต.ค. 2026 — ผู้ใช้ขอ) ไม่ต้องรออนุมัติใหม่
//          (แอดมินยังปิดองค์กรได้ถ้าแก้เป็นข้อมูลไม่เหมาะสม) — อีเวนต์ดึงชื่อองค์กรสดจาก users อยู่แล้ว ชื่อใหม่ขึ้นทันที
//          body: { name, orgType, description, contactEmail }
router.put('/me', authMiddleware, limitEdit, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('email organization');
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.organization?.status !== 'approved') {
      return res.status(403).json({ message: 'Only approved organizations can edit their details' });
    }
    const { error, fields } = readOrgFields(req.body, user.email);
    if (error) return res.status(400).json({ message: error });

    const updated = await User.findOneAndUpdate(
      { _id: user._id, 'organization.status': 'approved' },
      {
        $set: {
          'organization.name': fields.name,
          'organization.orgType': fields.orgType,
          'organization.description': fields.description,
          'organization.contactEmail': fields.contactEmail,
        },
      },
      { new: true, projection: { organization: 1 } }
    );
    if (!updated) return res.status(403).json({ message: 'Only approved organizations can edit their details' });

    // คำอธิบายของเควสเงา ("Event by <ชื่อ>") ให้ตรงชื่อใหม่
    const events = await OrgEvent.find({ orgUserId: user._id }).select('questId');
    await Quest.updateMany({ _id: { $in: events.map((e) => e.questId) } }, { description: `Event by ${fields.name}` });

    res.json({ message: 'Saved', organization: orgPayload(updated) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// อีเวนต์ — ฝั่งผู้เล่น
// ---------------------------------------------------------------------------

// @route   GET /api/org/events
// @desc    อีเวนต์ที่ยังไม่จบ (กำลังจะมา + กำลังจัด) ใกล้สุดก่อน 50 อัน
router.get('/events', authMiddleware, async (req, res) => {
  try {
    const now = new Date();
    const events = await OrgEvent.find({ status: 'scheduled', endAt: { $gt: now } })
      .sort({ startAt: 1 })
      .limit(50);
    res.json({ events: await toEventPayloads(events, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/org/events/joined
// @desc    อีเวนต์ที่ฉันลงทะเบียน/เข้าร่วม (ทุกสถานะ) ใหม่สุดก่อน 50 อัน
router.get('/events/joined', authMiddleware, async (req, res) => {
  try {
    const regs = await OrgEventRegistration.find({ userId: req.userId }).select('eventId');
    const events = await OrgEvent.find({ _id: { $in: regs.map((r) => r.eventId) } })
      .sort({ startAt: -1 })
      .limit(50);
    res.json({ events: await toEventPayloads(events, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/org/events/mine
// @desc    อีเวนต์ที่องค์กรของฉันสร้าง (ทุกสถานะ) ใหม่สุดก่อน 50 อัน
router.get('/events/mine', authMiddleware, async (req, res) => {
  try {
    const events = await OrgEvent.find({ orgUserId: req.userId }).sort({ startAt: -1 }).limit(50);
    res.json({ events: await toEventPayloads(events, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/org/events/:id
router.get('/events/:id', authMiddleware, async (req, res) => {
  try {
    const event = await findEvent(req.params.id);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    res.json({ event: await toEventPayload(event, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/org/events/:id/register
// @desc    ลงทะเบียนเข้าร่วม — ได้จนกว่างานจะจบ ไม่เกินจำนวนที่รับ / องค์กรลงทะเบียนงานตัวเองไม่ได้
router.post('/events/:id/register', authMiddleware, async (req, res) => {
  try {
    const event = await findEvent(req.params.id);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    if (String(event.orgUserId) === String(req.userId)) {
      return res.status(403).json({ message: 'You cannot join your own event' });
    }
    const phase = phaseOf(event);
    if (phase === 'cancelled') return res.status(409).json({ message: 'This event was cancelled' });
    if (phase === 'ended') return res.status(409).json({ message: 'This event has ended' });

    const taken = await OrgEventRegistration.countDocuments({ eventId: event._id });
    if (taken >= event.capacity) return res.status(409).json({ message: 'This event is full' });

    try {
      await OrgEventRegistration.create({ eventId: event._id, userId: req.userId });
    } catch (err) {
      if (err.code === 11000) return res.status(409).json({ message: 'You already joined this event' });
      throw err;
    }
    res.status(201).json({ message: 'Joined', event: await toEventPayload(event, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE /api/org/events/:id/register
// @desc    ยกเลิกการลงทะเบียน — ได้เฉพาะก่อนงานเริ่มและยังไม่ได้เช็คอิน
router.delete('/events/:id/register', authMiddleware, async (req, res) => {
  try {
    const event = await findEvent(req.params.id);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    if (phaseOf(event) !== 'upcoming' && event.status !== 'cancelled') {
      return res.status(409).json({ message: 'The event has already started' });
    }
    const removed = await OrgEventRegistration.findOneAndDelete({
      eventId: event._id, userId: req.userId, status: 'registered',
    });
    if (!removed) return res.status(404).json({ message: 'You have not joined this event' });
    res.json({ message: 'Cancelled', event: await toEventPayload(event, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/org/checkin
// @desc    สแกน QR ที่งาน -> ได้แต้มทันที — body: { code } (ข้อความทั้งหมดใน QR)
//          ยังไม่ได้ลงทะเบียนก็เช็คอินได้ถ้ายังมีที่ว่าง (walk-in)
router.post('/checkin', authMiddleware, limitCheckIn, async (req, res) => {
  try {
    const parsed = parseQr(req.body?.code);
    if (!parsed) return res.status(400).json({ message: 'This is not an EcoQuest event QR code' });
    if (parsed.expired) {
      return res.status(400).json({ message: 'This QR code has expired. Scan the code on the organizer\'s screen again' });
    }

    const event = await findEvent(parsed.eventId);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    if (String(event.orgUserId) === String(req.userId)) {
      return res.status(403).json({ message: 'You cannot check in to your own event' });
    }
    if (event.status === 'cancelled') return res.status(409).json({ message: 'This event was cancelled' });
    if (!checkInOpen(event)) return res.status(409).json({ message: 'Check-in is closed for this event' });

    let reg = await OrgEventRegistration.findOne({ eventId: event._id, userId: req.userId });
    if (reg && reg.status === 'attended') {
      return res.status(409).json({ message: 'You already checked in to this event' });
    }
    if (!reg) {
      const taken = await OrgEventRegistration.countDocuments({ eventId: event._id });
      if (taken >= event.capacity) return res.status(409).json({ message: 'This event is full' });
      try {
        reg = await OrgEventRegistration.create({ eventId: event._id, userId: req.userId });
      } catch (err) {
        if (err.code !== 11000) throw err; // สแกนซ้อนกัน 2 ครั้ง — อีกครั้งสร้างไปแล้ว ไป CAS ต่อด้านล่าง
      }
    }

    // CAS registered -> attended ใน query เดียว กันสแกนรัวๆ ได้แต้มซ้ำ
    const latched = await OrgEventRegistration.findOneAndUpdate(
      { eventId: event._id, userId: req.userId, status: 'registered' },
      { status: 'attended', attendedAt: new Date() },
      { new: true }
    );
    if (!latched) return res.status(409).json({ message: 'You already checked in to this event' });

    const quest = await Quest.findById(event.questId);
    let result;
    try {
      // มาร่วมงานจริงวันนี้ = นับ Daily Streak ด้วย (applyStreak) แบบเดียวกับสมาชิกปาร์ตี้
      result = quest ? await awardQuest(req.userId, quest, { applyStreak: true }) : null;
    } catch (err) {
      // ให้รางวัลพัง -> ปลด latch ให้สแกนใหม่ได้ ไม่ให้ค้างเป็น attended ทั้งที่ไม่ได้แต้ม
      await OrgEventRegistration.updateOne({ _id: latched._id }, { status: 'registered', attendedAt: null });
      throw err;
    }
    if (!result) return res.status(404).json({ message: 'User not found' });

    await OrgEventRegistration.updateOne(
      { _id: latched._id },
      { historyId: result.history._id, pointsEarned: result.reward.points, xpEarned: result.reward.xp }
    );
    try {
      await notifyQuestCompleted(req.userId, quest, result.history._id, result.reward.points);
    } catch (err) {
      console.error('สร้างแจ้งเตือนเช็คอินไม่สำเร็จ:', err.message);
    }

    res.status(201).json({
      message: 'Checked in',
      earned: { points: result.reward.points, xp: result.reward.xp },
      newAchievements: result.newAchievements || [],
      streakMilestone: result.streakMilestone || null,
      bingo: result.bingo || null,
      event: await toEventPayload(event, req.userId),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// อีเวนต์ — ฝั่งองค์กร
// ---------------------------------------------------------------------------

const requireApprovedOrg = async (req, res, next) => {
  try {
    const user = await User.findById(req.userId).select('organization');
    if (!user || user.organization?.status !== 'approved') {
      return res.status(403).json({ message: 'Only approved organizations can do this' });
    }
    req.orgUser = user;
    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// เจ้าของอีเวนต์เท่านั้น (แนบ req.event)
const loadOwnEvent = async (req, res, next) => {
  try {
    const event = await findEvent(req.params.id);
    if (!event) return res.status(404).json({ message: 'Event not found' });
    if (String(event.orgUserId) !== String(req.userId)) {
      return res.status(403).json({ message: 'This is not your event' });
    }
    req.event = event;
    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// @route   POST /api/org/events
// @desc    สร้างอีเวนต์ — body: { title, description, category, location, startAt, endAt, capacity, points }
router.post('/events', authMiddleware, limitCreate, requireApprovedOrg, async (req, res) => {
  try {
    const b = req.body || {};
    const title = str(b.title);
    const description = str(b.description);
    const category = str(b.category);
    const location = str(b.location);
    const startAt = toDate(b.startAt);
    const endAt = toDate(b.endAt);
    const capacity = toInt(b.capacity);
    const points = toInt(b.points);
    const now = Date.now();

    if (title.length < 3 || title.length > 60) return res.status(400).json({ message: 'Title must be 3–60 characters' });
    if (description.length > 1000) return res.status(400).json({ message: 'Description is too long (max 1000 characters)' });
    if (!CATEGORIES.includes(category)) return res.status(400).json({ message: 'Choose a category' });
    if (location.length < 2 || location.length > 120) return res.status(400).json({ message: 'Enter the location (2–120 characters)' });
    if (!startAt || !endAt) return res.status(400).json({ message: 'Enter the start and end time' });
    if (startAt.getTime() < now - 5 * 60 * 1000) return res.status(400).json({ message: 'The start time has already passed' });
    if (startAt.getTime() > now + MAX_DAYS_AHEAD * 24 * 60 * 60 * 1000) {
      return res.status(400).json({ message: `Events can be created up to ${MAX_DAYS_AHEAD} days ahead` });
    }
    const duration = endAt.getTime() - startAt.getTime();
    if (duration < MIN_DURATION_MS) return res.status(400).json({ message: 'The event must be at least 15 minutes long' });
    if (duration > MAX_DURATION_MS) return res.status(400).json({ message: 'The event can be at most 8 hours long' });
    if (!Number.isInteger(capacity) || capacity < 1 || capacity > MAX_CAPACITY) {
      return res.status(400).json({ message: `Capacity must be 1–${MAX_CAPACITY} people` });
    }
    if (!Number.isInteger(points) || points < ORG_POINTS_MIN || points > ORG_POINTS_MAX) {
      return res.status(400).json({ message: `Points must be ${ORG_POINTS_MIN}–${ORG_POINTS_MAX}` });
    }

    const dayStart = startOfDayFor(startAt);
    const sameDay = await OrgEvent.countDocuments({
      orgUserId: req.userId,
      status: 'scheduled',
      startAt: { $gte: dayStart, $lt: new Date(dayStart.getTime() + 24 * 60 * 60 * 1000) },
    });
    if (sameDay >= MAX_EVENTS_PER_DAY) {
      return res.status(409).json({ message: `You can have at most ${MAX_EVENTS_PER_DAY} events on the same day` });
    }

    const orgName = req.orgUser.organization.name;
    // เควสเงา — ให้การเช็คอินได้แต้มผ่าน awardQuest (ประวัติโชว์ชื่ออีเวนต์, นับเหรียญตามหมวด)
    const quest = await Quest.create({
      title,
      description: `Event by ${orgName}`,
      detail: description,
      category,
      type: 'org',
      difficulty: 'medium',
      impact: 'medium',
      scorePoints: points,
      xpReward: points,
      location,
      capacity,
    });
    let event;
    try {
      event = await OrgEvent.create({
        orgUserId: req.userId,
        questId: quest._id,
        title, description, category, location, startAt, endAt, capacity, points,
      });
    } catch (err) {
      await Quest.deleteOne({ _id: quest._id });
      throw err;
    }
    res.status(201).json({ message: 'Event created', event: await toEventPayload(event, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/org/events/:id/cancel
// @desc    ยกเลิกอีเวนต์ — ได้เฉพาะก่อนงานเริ่ม (เริ่มแล้วมีคนได้แต้มไปแล้ว) แจ้งทุกคนที่ลงทะเบียน
router.post('/events/:id/cancel', authMiddleware, loadOwnEvent, async (req, res) => {
  try {
    if (req.event.status === 'cancelled') return res.status(409).json({ message: 'This event is already cancelled' });
    if (phaseOf(req.event) !== 'upcoming') return res.status(409).json({ message: 'The event has already started' });
    // เช็คอินเปิดก่อนงานเริ่ม 30 นาที — มีคนได้แต้มไปแล้วก็ยกเลิกไม่ได้
    if (await OrgEventRegistration.exists({ eventId: req.event._id, status: 'attended' })) {
      return res.status(409).json({ message: 'People have already checked in to this event' });
    }
    const event = await cancelEvent(req.event._id);
    if (!event) return res.status(409).json({ message: 'This event is already cancelled' });
    res.json({ message: 'Event cancelled', event: await toEventPayload(event, req.userId) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/org/events/:id/attendees
// @desc    รายชื่อคนลงทะเบียน + ใครเช็คอินแล้ว (เจ้าของอีเวนต์) — เช็คอินแล้วขึ้นก่อน
router.get('/events/:id/attendees', authMiddleware, loadOwnEvent, async (req, res) => {
  try {
    const regs = await OrgEventRegistration.find({ eventId: req.event._id })
      .sort({ attendedAt: -1, createdAt: 1 })
      .populate('userId', 'displayName level avatarContentType avatarUpdatedAt');
    const attendees = regs
      .filter((r) => r.userId)
      .map((r) => ({
        userId: r.userId._id,
        displayName: r.userId.displayName,
        level: r.userId.level,
        avatarUrl: avatarUrlFor(r.userId),
        status: r.status,
        joinedAt: r.createdAt,
        attendedAt: r.attendedAt,
      }));
    res.json({ event: await toEventPayload(req.event, req.userId), attendees });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/org/events/:id/qr
// @desc    ข้อความ QR ปัจจุบัน (เปลี่ยนทุก 30 วิ) — เจ้าของอีเวนต์ที่ยังเป็นองค์กรที่อนุมัติอยู่ และอยู่ในช่วงเช็คอินเท่านั้น
router.get('/events/:id/qr', authMiddleware, requireApprovedOrg, loadOwnEvent, async (req, res) => {
  try {
    const event = req.event;
    if (event.status === 'cancelled') return res.status(409).json({ message: 'This event was cancelled' });
    if (!checkInOpen(event)) {
      const opens = new Date(event.startAt.getTime() - CHECKIN_EARLY_MS);
      return res.status(409).json({
        message: Date.now() < opens.getTime()
          ? 'Check-in opens 30 minutes before the event starts'
          : 'Check-in is closed for this event',
        opensAt: opens,
      });
    }
    res.json(qrFor(String(event._id)));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ---------------------------------------------------------------------------
// แอดมิน — อนุมัติ/ไม่อนุมัติ/ปิดองค์กร
// ---------------------------------------------------------------------------

// @route   GET /api/org/admin/requests?status=pending
router.get('/admin/requests', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const status = ['pending', 'approved', 'rejected', 'suspended'].includes(req.query.status)
      ? req.query.status
      : 'pending';
    const users = await User.find({ 'organization.status': status })
      .sort({ 'organization.requestedAt': -1 })
      .limit(100)
      .select('email displayName avatarContentType avatarUpdatedAt organization');
    res.json({
      requests: users.map((u) => ({
        userId: u._id,
        email: u.email,
        displayName: u.displayName,
        avatarUrl: avatarUrlFor(u),
        organization: orgPayload(u),
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/org/admin/:userId/decide
// @desc    body: { action: 'approve' | 'reject' | 'suspend', note }
//          approve: pending/suspended -> approved / reject: pending -> rejected / suspend: approved -> suspended
//          (ปิดองค์กร = ยกเลิกอีเวนต์ที่ยังไม่เริ่มทั้งหมด + แจ้งคนที่ลงทะเบียน)
const TRANSITIONS = {
  approve: { from: ['pending', 'suspended'], to: 'approved' },
  reject: { from: ['pending'], to: 'rejected' },
  suspend: { from: ['approved'], to: 'suspended' },
};
router.post('/admin/:userId/decide', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const t = TRANSITIONS[str(req.body?.action)];
    if (!t) return res.status(400).json({ message: 'Unknown action' });
    if (!mongoose.isValidObjectId(req.params.userId)) return res.status(404).json({ message: 'User not found' });
    const note = str(req.body?.note).slice(0, 300);

    const user = await User.findOneAndUpdate(
      { _id: req.params.userId, 'organization.status': { $in: t.from } },
      { $set: { 'organization.status': t.to, 'organization.decidedAt': new Date(), 'organization.decisionNote': note } },
      { new: true, projection: { organization: 1, email: 1, displayName: 1 } }
    );
    if (!user) return res.status(409).json({ message: 'This request was already handled' });

    let cancelledEvents = 0;
    if (t.to === 'suspended') {
      const upcoming = await OrgEvent.find({ orgUserId: user._id, status: 'scheduled', startAt: { $gt: new Date() } }).select('_id');
      for (const e of upcoming) {
        if (await cancelEvent(e._id)) cancelledEvents += 1;
      }
    }
    try {
      await notifyOrgStatus(user._id, user.organization);
    } catch (err) {
      console.error('แจ้งผลองค์กรไม่สำเร็จ:', err.message);
    }
    res.json({ message: 'Done', organization: orgPayload(user), cancelledEvents });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
module.exports.ORG_RULES = { ORG_POINTS_MIN, ORG_POINTS_MAX, MAX_EVENTS_PER_DAY };
