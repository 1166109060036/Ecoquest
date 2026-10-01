// Eco Bingo รายสัปดาห์ (อาจารย์อยากให้ "อยากทำเควสต่อไปเรื่อยๆ" — ผู้ใช้เลือก 30 ก.ย. 2026)
// ทุกสัปดาห์ (จันทร์ 00:00 เวลาญี่ปุ่น) แต่ละคนได้การ์ด 3x3: ช่องกลางฟรี อีก 8 ช่องเป็นเควส solo คนละชุด
// ช่องติดเมื่อเควสนั้น "ได้รางวัลแล้ว" ในสัปดาห์นั้น (ผ่านการตรวจ / Check Food) — นับตามเวลาที่ทำ ไม่ใช่เวลาที่ตรวจผ่าน
// ครบแถว (แนวนอน/ตั้ง/ทแยง รวม 8 แถว) = LINE_REWARD ต่อแถว / ครบทั้งการ์ด = FULL_REWARD เพิ่ม
//
// ให้รางวัลแบบ atomic ต่อแถว ($addToSet แบบมีเงื่อนไข) — ตรวจผ่านพร้อมกันหลายใบ/เปิดหน้า Bingo พร้อมกันไม่ได้ซ้ำ
// เรียกจาก 2 ที่: utils/questRewards.js#awardQuest (หลังให้รางวัลเควส) และ GET /api/bingo (เก็บตกถ้ารอบก่อนพัง)
const crypto = require('crypto');
const BingoCard = require('../models/BingoCard');
const Quest = require('../models/Quest');
const QuestHistory = require('../models/QuestHistory');
const QuestSubmission = require('../models/QuestSubmission');
const User = require('../models/User');
const progression = require('./progression');
const { notifyBingo } = require('./notifications');
const { startOfWeekFor, weekKeyFor, DAY_MS } = require('./questDay');

const FREE_INDEX = 4;
const LINES = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], // แนวนอน
  [0, 3, 6], [1, 4, 7], [2, 5, 8], // แนวตั้ง
  [0, 4, 8], [2, 4, 6], // ทแยง
];
// เทียบ: เควส Easy 10 P — ครบทั้งการ์ด (8 แถว + โบนัส) = 170 P/สัปดาห์ ต้องทำเควสต่างกัน 8 อันซึ่งได้แต้มเองอีก ~80+
const LINE_REWARD = { points: 15, xp: 15 };
const FULL_REWARD = { points: 50, xp: 50 };

const weekHash = (userId, weekKey, questId) =>
  crypto.createHash('sha256').update(`bingo-${userId}-${weekKey}-${questId}`).digest().readUInt32BE(0);

// เควสที่ลงการ์ดได้: solo ที่เปิดอยู่ ทำจบในครั้งเดียว และโชว์ใน Explore ทุกวัน (ไม่อยู่กลุ่มสุ่มแบบ Food Saver)
const eligibleQuests = () =>
  Quest.find({
    isActive: true,
    type: 'solo',
    randomPool: null,
    $or: [{ durationDays: { $exists: false } }, { durationDays: { $lte: 1 } }],
  }).select('_id');

// สุ่มแบบคงที่ทั้งสัปดาห์ (hash ของ user + สัปดาห์) — แนวเดียวกับ utils/questSelection.js
const pickCells = (userId, weekKey, quests) => {
  const picked = quests
    .map((q) => ({ id: q._id, h: weekHash(userId, weekKey, q._id) }))
    .sort((a, b) => a.h - b.h)
    .slice(0, 8)
    .map((x) => x.id);
  while (picked.length < 8) picked.push(null); // เควสไม่พอ = ช่องฟรีเพิ่ม
  return [...picked.slice(0, FREE_INDEX), null, ...picked.slice(FREE_INDEX)];
};

const getOrCreateCard = async (userId, date = new Date()) => {
  const weekKey = weekKeyFor(date);
  const existing = await BingoCard.findOne({ userId, weekKey });
  if (existing) return existing;
  const cells = pickCells(String(userId), weekKey, await eligibleQuests());
  try {
    return await BingoCard.findOneAndUpdate(
      { userId, weekKey },
      { $setOnInsert: { userId, weekKey, cells } },
      { upsert: true, new: true }
    );
  } catch (err) {
    // สร้างพร้อมกัน 2 request ชน unique index — อีกอันสร้างไปแล้ว อ่านของมันแทน
    if (err.code === 11000) return BingoCard.findOne({ userId, weekKey });
    throw err;
  }
};

const weekRange = (weekKey) => {
  // weekKey เป็นวันที่ท้องถิ่นของวันจันทร์ — เที่ยงวันของวันนั้น (UTC) ตกอยู่ในสัปดาห์นั้นเสมอไม่ว่า offset เท่าไหร่
  const start = startOfWeekFor(new Date(`${weekKey}T12:00:00Z`));
  return { start, end: new Date(start.getTime() + 7 * DAY_MS) };
};

// เควสบนการ์ดที่ถูกปิดใช้งาน/ลบไปหลังสุ่มการ์ดแล้ว — ผู้เล่นทำไม่ได้แล้ว นับเป็นช่องฟรี ไม่ให้แถวนั้นตายถาวร
const retiredQuestIds = async (card) => {
  const questIds = card.cells.filter(Boolean);
  const active = await Quest.find({ _id: { $in: questIds }, isActive: true }).distinct('_id');
  const activeSet = new Set(active.map(String));
  return new Set(questIds.map(String).filter((id) => !activeSet.has(id)));
};

// เควสบนการ์ดที่ได้รางวัลแล้วในสัปดาห์นั้น (แถวเช็คอินระหว่างทางไม่นับ — การ์ดไม่มีเควสหลายวันอยู่แล้ว)
// + เควสที่ถูกปิดไปแล้ว (นับเหมือนช่องฟรี)
const doneQuestIds = async (userId, card) => {
  const { start, end } = weekRange(card.weekKey);
  const questIds = card.cells.filter(Boolean);
  const [done, retired] = await Promise.all([
    QuestHistory.distinct('questId', {
      userId,
      questId: { $in: questIds },
      checkIn: { $ne: true },
      completedAt: { $gte: start, $lt: end },
    }),
    retiredQuestIds(card),
  ]);
  return new Set([...done.map(String), ...retired]);
};

const cellDone = (card, done, i) => card.cells[i] === null || card.cells[i] === undefined || done.has(String(card.cells[i]));

const grant = async (userId, { points, xp }) => {
  const user = await User.findByIdAndUpdate(userId, { $inc: { points, xp } }, { new: true, projection: { xp: 1 } });
  if (user) await User.updateOne({ _id: userId }, { $set: { level: progression.levelFromXp(user.xp) } });
};

// ให้รางวัลแถว/การ์ดที่ครบแล้วแต่ยังไม่ได้รับ — คืน { lines, full, points, xp } หรือ null ถ้าไม่มีอะไรใหม่
const settleCard = async (userId, card) => {
  const done = await doneQuestIds(userId, card);
  const completeLines = LINES.map((line, idx) => (line.every((i) => cellDone(card, done, i)) ? idx : -1)).filter(
    (idx) => idx >= 0
  );

  const newLines = [];
  for (const idx of completeLines) {
    if (card.claimedLines.includes(idx)) continue;
    const claimed = await BingoCard.updateOne(
      { _id: card._id, claimedLines: { $ne: idx } },
      { $addToSet: { claimedLines: idx } }
    );
    if (claimed.modifiedCount === 1) newLines.push(idx);
  }

  let full = false;
  const allDone = card.cells.every((_, i) => cellDone(card, done, i));
  if (allDone && !card.fullClaimed) {
    const claimed = await BingoCard.updateOne({ _id: card._id, fullClaimed: false }, { $set: { fullClaimed: true } });
    full = claimed.modifiedCount === 1;
  }

  if (newLines.length === 0 && !full) return null;
  const points = newLines.length * LINE_REWARD.points + (full ? FULL_REWARD.points : 0);
  const xp = newLines.length * LINE_REWARD.xp + (full ? FULL_REWARD.xp : 0);
  await grant(userId, { points, xp });
  try {
    await notifyBingo(userId, { weekKey: card.weekKey, lines: newLines, full, points, xp });
  } catch (err) {
    console.error('สร้างแจ้งเตือน Bingo ไม่สำเร็จ:', err.message);
  }
  return { lines: newLines, full, points, xp };
};

// หลังให้รางวัลเควส 1 ครั้ง (utils/questRewards.js#awardQuest) — เช็คการ์ดของสัปดาห์ที่ "ทำ" เควสนั้น
const onQuestAwarded = async (userId, questId, completedAt) => {
  const card = await getOrCreateCard(userId, completedAt);
  if (!card.cells.some((c) => c && String(c) === String(questId))) return null;
  return settleCard(userId, card);
};

// GET /api/bingo — การ์ดสัปดาห์นี้พร้อมสถานะแต่ละช่อง
const bingoPayload = async (userId) => {
  let card = await getOrCreateCard(userId);
  const settled = await settleCard(userId, card); // เก็บตกแถวที่ครบแล้วแต่รอบก่อนให้รางวัลไม่สำเร็จ
  if (settled) card = await BingoCard.findById(card._id);

  const { start, end } = weekRange(card.weekKey);
  const questIds = card.cells.filter(Boolean);
  const [done, quests, pending] = await Promise.all([
    doneQuestIds(userId, card),
    Quest.find({ _id: { $in: questIds } }).select('title category imageKey difficulty scorePoints isActive'),
    QuestSubmission.distinct('questId', {
      userId,
      status: 'pending',
      questId: { $in: questIds },
      createdAt: { $gte: start, $lt: end },
    }),
  ]);
  const questById = new Map(quests.map((q) => [String(q._id), q]));
  const pendingSet = new Set(pending.map(String));

  const cells = card.cells.map((c, i) => {
    if (!c) return { index: i, free: true, done: true };
    const q = questById.get(String(c));
    // เควสถูกปิด/ลบไปหลังสุ่มการ์ด = ช่องฟรี (นับครบแถวได้ใน doneQuestIds แล้ว)
    if (!q || q.isActive === false) return { index: i, free: true, done: true };
    return {
      index: i,
      free: false,
      questId: c,
      title: q ? q.title : 'Quest',
      category: q ? q.category : null,
      imageKey: q ? q.imageKey : null,
      done: done.has(String(c)),
      pending: !done.has(String(c)) && pendingSet.has(String(c)),
    };
  });
  const completeLines = LINES.map((line, idx) => (line.every((i) => cells[i].done) ? idx : -1)).filter((i) => i >= 0);

  return {
    weekKey: card.weekKey,
    weekEndsAt: end,
    cells,
    lines: LINES,
    completeLines,
    doneCount: cells.filter((c) => !c.free && c.done).length,
    questCount: cells.filter((c) => !c.free).length,
    full: card.fullClaimed,
    lineReward: LINE_REWARD,
    fullReward: FULL_REWARD,
    justClaimed: settled,
  };
};

module.exports = {
  FREE_INDEX,
  LINES,
  LINE_REWARD,
  FULL_REWARD,
  pickCells,
  getOrCreateCard,
  settleCard,
  onQuestAwarded,
  bingoPayload,
};
