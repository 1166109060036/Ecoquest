// Daily Variety Combo (อาจารย์อยากให้ "อยากทำเควสต่อไปเรื่อยๆ" แทนการจำกัด — ผู้ใช้เลือก 30 ก.ย. 2026)
// ทำเควส solo ที่ "ไม่ซ้ำกัน" ในวันเดียวกัน = แต้ม/XP คูณเพิ่มขึ้นเรื่อยๆ / ทำเควสเดิมซ้ำในวันเดียวกัน = ได้น้อยลงเรื่อยๆ
// (ไม่ได้ห้ามทำซ้ำ แค่ไม่คุ้ม) — คูณเฉพาะแต้ม/XP ไม่แตะ CO2 (CO2 นับเควสละครั้งต่อวันอยู่แล้ว profilePayload.js)
//
// ลำดับในวัน = ลำดับเวลาที่ "ทำ" (ส่งหลักฐาน / Check Food กดจบ) ไม่ใช่ลำดับที่ตรวจผ่าน — แต่คิดตัวคูณจริงตอนให้รางวัล
// (ตอนผ่าน) โดยไม่นับอันที่ไม่ผ่าน กันส่งรูปมั่วเพื่อดันคอมโบแล้วค่อยส่งของจริง
// ครอบคลุม: submission kind 'quest' (ไม่ใช่ party / เช็คอินเควสหลายวัน) + Check Food (ไม่มี submission มีแค่ QuestHistory)
const QuestSubmission = require('../models/QuestSubmission');
const QuestHistory = require('../models/QuestHistory');
const Quest = require('../models/Quest');
const { startOfDayFor, DAY_MS } = require('./questDay');

const COMBO_STEP = 0.1; // เควสใหม่แต่ละอันในวันเดียวกัน +0.1
const COMBO_MAX = 1.5; // เพดาน (เควสไม่ซ้ำอันที่ 6 ขึ้นไป)
const REPEAT_STEP = 0.25; // ทำซ้ำแต่ละครั้ง -0.25
const REPEAT_MIN = 0.25; // ต่ำสุด

const round2 = (n) => Math.round(n * 100) / 100;

// ตัวคูณของเควส `questId` ถ้าก่อนหน้านี้ในวันเดียวกันทำ `prevQuestIds` ไปแล้ว (เรียงตามเวลา)
const comboFor = (prevQuestIds, questId) => {
  const id = String(questId);
  const prev = prevQuestIds.map(String);
  const repeatIndex = prev.filter((q) => q === id).length;
  const distinct = new Set(prev);
  if (repeatIndex > 0) {
    return {
      multiplier: round2(Math.max(REPEAT_MIN, 1 - REPEAT_STEP * repeatIndex)),
      repeat: true,
      distinctToday: distinct.size,
    };
  }
  const distinctIndex = distinct.size + 1; // เควสนี้เป็นอันไม่ซ้ำลำดับที่เท่าไหร่ของวัน
  return {
    multiplier: round2(Math.min(COMBO_MAX, 1 + COMBO_STEP * (distinctIndex - 1))),
    repeat: false,
    distinctToday: distinctIndex,
  };
};

// ตัวคูณของเควสใหม่อันถัดไป (ยังไม่เคยทำวันนี้) — แอพโชว์ "next new quest ×1.3"
const nextNewMultiplier = (distinctSoFar) => round2(Math.min(COMBO_MAX, 1 + COMBO_STEP * distinctSoFar));

let fridgeQuestIdsCache = null;
const fridgeQuestIds = async () => {
  if (!fridgeQuestIdsCache) {
    fridgeQuestIdsCache = await Quest.find({ actionKey: 'fridge_check' }).distinct('_id');
  }
  return fridgeQuestIdsCache;
};

// เควสที่นับคอมโบของ user ในวันที่ `at` อยู่ เรียงตามเวลาที่ทำ — ไม่นับอันที่ไม่ผ่านการตรวจ
// before: นับเฉพาะที่ทำก่อนเวลานี้ / excludeSubmissionId: ไม่นับ submission ตัวที่กำลังคิดอยู่เอง
const entriesOfDay = async (userId, at, { before = null, excludeSubmissionId = null } = {}) => {
  const dayStart = startOfDayFor(at);
  const dayEnd = new Date(dayStart.getTime() + DAY_MS);
  const until = before ? new Date(Math.min(before.getTime(), dayEnd.getTime())) : dayEnd;

  const [subs, fridge] = await Promise.all([
    QuestSubmission.find({
      userId,
      kind: 'quest',
      status: { $ne: 'rejected' },
      createdAt: { $gte: dayStart, $lt: until },
      ...(excludeSubmissionId ? { _id: { $ne: excludeSubmissionId } } : {}),
    }).select('questId createdAt'),
    QuestHistory.find({
      userId,
      questId: { $in: await fridgeQuestIds() },
      checkIn: { $ne: true },
      completedAt: { $gte: dayStart, $lt: until },
    }).select('questId completedAt'),
  ]);

  return [
    ...subs.map((s) => ({ questId: String(s.questId), at: s.createdAt })),
    ...fridge.map((h) => ({ questId: String(h.questId), at: h.completedAt })),
  ]
    .sort((a, b) => a.at - b.at)
    .map((e) => e.questId);
};

// คอมโบของ submission ที่กำลังให้รางวัล (ตอนผ่าน) / ที่เพิ่งส่ง (ตัวอย่างให้แอพโชว์)
const comboForSubmission = async (submission) => {
  const prev = await entriesOfDay(submission.userId, submission.createdAt, {
    before: submission.createdAt,
    excludeSubmissionId: submission._id,
  });
  return comboFor(prev, submission.questId);
};

// คอมโบของการทำเควส `questId` "ตอนนี้" (Check Food ให้รางวัลทันที / หน้า Explore โชว์ตัวอย่าง)
const comboForNow = async (userId, questId) => {
  const now = new Date();
  return comboFor(await entriesOfDay(userId, now, { before: now }), questId);
};

// สรุปคอมโบวันนี้ + ตัวคูณของทุกเควส (หน้า Explore) — query ครั้งเดียว
const comboSummaryToday = async (userId) => {
  const now = new Date();
  const prev = await entriesOfDay(userId, now, { before: now });
  const distinctToday = new Set(prev).size;
  return {
    distinctToday,
    nextNewMultiplier: nextNewMultiplier(distinctToday),
    maxMultiplier: COMBO_MAX,
    previewFor: (questId) => comboFor(prev, questId).multiplier,
  };
};

// คูณแต้ม/XP — ปัดเศษ, ได้อย่างน้อย 1 ถ้าฐานไม่ใช่ 0
const applyCombo = (reward, multiplier) => {
  if (!multiplier || multiplier === 1) return { ...reward };
  const scale = (v) => (v > 0 ? Math.max(1, Math.round(v * multiplier)) : v);
  return { ...reward, points: scale(reward.points), xp: scale(reward.xp) };
};

module.exports = {
  COMBO_STEP,
  COMBO_MAX,
  REPEAT_STEP,
  REPEAT_MIN,
  comboFor,
  nextNewMultiplier,
  comboForSubmission,
  comboForNow,
  comboSummaryToday,
  applyCombo,
};
