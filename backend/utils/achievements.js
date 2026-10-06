const mongoose = require('mongoose');
const Achievement = require('../models/Achievement');
const QuestHistory = require('../models/QuestHistory');
const { notifyAchievementUnlocked } = require('./notifications');

// รวมนิยามเหรียญทั้งหมดไว้ไฟล์เดียว — อยากเพิ่ม/แก้เงื่อนไขปลดล็อกแก้ที่นี่ที่เดียว
// (แนวเดียวกับ progression.js ที่รวมสูตร level ไว้ที่เดียว)
//
// เหรียญหลายขั้น (ผู้ใช้สั่ง 6 ต.ค. 2026): แต่ละหมวดมี Bronze / Silver / Gold — ทำ quest ในหมวดนั้นครบตามจำนวน
// "required" ของขั้นนั้น (นับทุกครั้งที่ได้รางวัล รวมทำซ้ำ / แถวเช็คอินระหว่างทางของเควสหลายวันไม่นับ)
// เดิมมีขั้นเดียว (10 ครั้ง) ผู้เล่นทั่วไปได้ครบทุกหมวดใน ~1 เดือนแล้วไม่มีเป้าต่อ (BALANCE_REPORT.md 2 ต.ค. 2026)
//
// ⚠️ การเก็บใน DB (Achievement.medalType): ขั้น Bronze ใช้ medalType เดิมเป๊ะ ('food_saver') — เหรียญที่ปลดล็อกไปก่อนมีขั้น
//    นับเป็น Bronze อัตโนมัติ ไม่ต้อง migrate / ขั้นอื่นต่อท้าย ':silver' ':gold' ('food_saver:silver')
//    ห้ามเปลี่ยน medalType หรือชื่อ tier หลังมีคนปลดล็อกไปแล้ว (unique index (userId, medalType))
const TIERS = ['bronze', 'silver', 'gold'];
const TIER_LABEL = { bronze: 'Bronze', silver: 'Silver', gold: 'Gold' };

const MEDALS = [
  { medalType: 'food_saver', title: 'Food Saver', category: 'food_waste', required: [10, 30, 75] },
  { medalType: 'recycling', title: 'Recycling', category: 'recycling', required: [10, 30, 75] },
  { medalType: 'plastic_reduction', title: 'Plastic Reduction', category: 'plastic', required: [10, 30, 75] },
  // เพิ่มทีหลังตอน seed quest จริง เพราะมีหมวด energy — ไม่มีเหรียญนี้ quest ประหยัดพลังงานจะไม่มีรางวัลระยะยาว
  { medalType: 'energy_saver', title: 'Energy Saver', category: 'energy', required: [10, 30, 75] },
  // community = party quest (ลงพื้นที่จริง นัดรวมกลุ่ม) ทำได้ไม่บ่อย เลยตั้งเกณฑ์ต่ำกว่า
  { medalType: 'community', title: 'Community', category: 'community', required: [1, 5, 15] },
];

// คีย์ใน DB ของเหรียญหมวดนี้ขั้นนี้ (Bronze = medalType เดิม — ดูหมายเหตุด้านบน)
const tierKey = (medal, tier) => (tier === 'bronze' ? medal.medalType : `${medal.medalType}:${tier}`);

// แยกคีย์ใน DB กลับเป็น { medal, tier } — คีย์ที่ไม่รู้จัก (เหรียญที่เลิกใช้) คืน null
const parseTierKey = (key) => {
  const [base, tier = 'bronze'] = String(key).split(':');
  const medal = MEDALS.find((m) => m.medalType === base);
  return medal && TIERS.includes(tier) ? { medal, tier } : null;
};

const describeCount = (medal, required) => {
  const cat = medal.category.replace('_', ' ');
  return required === 1 ? `Complete a ${cat} quest` : `Complete ${required} ${cat} quests`;
};

// นับว่า user ทำ quest สำเร็จไปกี่ครั้งในแต่ละหมวด
// ต้อง join ไปหา Quest เพราะ QuestHistory เก็บแค่ questId ไม่ได้เก็บหมวดไว้ด้วย
const countByCategory = async (userId) => {
  // ⚠️ aggregate ไม่ cast string -> ObjectId ให้อัตโนมัติเหมือน find() ต้องแปลงเอง
  //    ถ้าส่ง req.userId (string) เข้าไปตรงๆ จะ match ไม่เจอเลยและได้ 0 ทุกหมวดแบบเงียบๆ
  const rows = await QuestHistory.aggregate([
    // แถวเช็คอินระหว่างทางของเควสหลายวันไม่นับ — เควส 7 วันนับเป็นทำสำเร็จ 1 ครั้งตอนจบเท่านั้น
    { $match: { userId: new mongoose.Types.ObjectId(String(userId)), checkIn: { $ne: true } } },
    {
      $lookup: {
        from: 'quests',
        localField: 'questId',
        foreignField: '_id',
        as: 'quest',
      },
    },
    { $unwind: '$quest' },
    { $group: { _id: '$quest.category', count: { $sum: 1 } } },
  ]);

  const counts = {};
  for (const row of rows) counts[row._id] = row.count;
  return counts;
};

// สถานะเหรียญทั้งหมดของ user — 1 แถวต่อหมวด พร้อมสถานะทุกขั้น
// ฟิลด์เดิม (medalType/title/description/required/progress/unlocked/unlockedAt) คงไว้ให้แอพเวอร์ชันเก่าอ่านได้:
//   unlocked/unlockedAt = ขั้น Bronze / required+progress = ของขั้นถัดไป (ครบทุกขั้นแล้ว = ของขั้นสุดท้าย)
const getAchievements = async (userId) => {
  const [counts, unlockedRows] = await Promise.all([
    countByCategory(userId),
    Achievement.find({ userId }).select('medalType unlockedAt'),
  ]);
  const unlockedMap = new Map(unlockedRows.map((a) => [a.medalType, a.unlockedAt]));

  return MEDALS.map((medal) => {
    const count = counts[medal.category] || 0;
    const tiers = TIERS.map((tier, i) => {
      const key = tierKey(medal, tier);
      return {
        tier,
        label: TIER_LABEL[tier],
        required: medal.required[i],
        unlocked: unlockedMap.has(key),
        unlockedAt: unlockedMap.get(key) || null,
      };
    });
    // ขั้นสูงสุดที่ปลดล็อกแล้ว (นับเรียงจากล่าง — ขั้นบนปลดล็อกได้ทีหลังขั้นล่างเสมอใน syncAchievements)
    const reached = tiers.filter((t) => t.unlocked);
    const top = reached.length ? reached[reached.length - 1] : null;
    const next = tiers.find((t) => !t.unlocked) || null;
    const target = next || tiers[tiers.length - 1];

    return {
      medalType: medal.medalType,
      title: medal.title,
      description: describeCount(medal, target.required),
      category: medal.category,
      // ของขั้นถัดไป — ตัดไม่ให้เกิน required เพื่อให้ progress bar ฝั่งแอพไม่ล้น
      required: target.required,
      progress: Math.min(count, target.required),
      unlocked: tiers[0].unlocked,
      unlockedAt: tiers[0].unlockedAt,
      // ---- เหรียญหลายขั้น ----
      count,
      tier: top ? top.tier : null, // ขั้นสูงสุดที่ได้แล้ว (null = ยังไม่ได้สักขั้น)
      tierLabel: top ? top.label : null,
      tierUnlockedAt: top ? top.unlockedAt : null,
      nextTier: next ? next.tier : null, // null = ครบทุกขั้นแล้ว
      nextRequired: next ? next.required : null,
      maxed: !next,
      tiers,
    };
  });
};

// เช็คว่ามีเหรียญขั้นไหนเพิ่งเข้าเงื่อนไขบ้าง แล้วบันทึกลง DB (ปลดล็อกทีละขั้นจากล่างขึ้นบน)
// คืนเฉพาะ "ขั้นที่เพิ่งปลดล็อกรอบนี้" เพื่อให้แอพเอาไปเด้งฉลองได้
const syncAchievements = async (userId) => {
  const counts = await countByCategory(userId);
  const already = await Achievement.find({ userId }).select('medalType');
  const alreadySet = new Set(already.map((a) => a.medalType));

  const newlyUnlocked = [];
  for (const medal of MEDALS) {
    const count = counts[medal.category] || 0;
    for (let i = 0; i < TIERS.length; i++) {
      const tier = TIERS[i];
      const key = tierKey(medal, tier);
      if (alreadySet.has(key)) continue;
      if (count < medal.required[i]) break; // ขั้นนี้ยังไม่ถึง ขั้นที่สูงกว่าก็ยังไม่ถึงแน่นอน

      try {
        await Achievement.create({ userId, medalType: key });
        const unlocked = {
          medalType: key,
          baseMedalType: medal.medalType,
          // title รวมชื่อขั้นไว้เลย — แอพเวอร์ชันเก่าที่โชว์แค่ title/description ก็ยังเห็นว่าได้ขั้นไหน
          title: `${medal.title} · ${TIER_LABEL[tier]}`,
          description: describeCount(medal, medal.required[i]),
          tier,
          category: medal.category,
        };
        newlyUnlocked.push(unlocked);
        // ใส่ไว้ที่นี่ที่เดียวเพื่อครอบคลุมทั้ง 2 ทางที่ปลดล็อกเหรียญได้ (quest เดี่ยว + party fan-out)
        // ไม่ทำให้ทั้งฟังก์ชันพังถ้าสร้างแจ้งเตือนไม่สำเร็จ เพราะเหรียญปลดล็อกไปแล้วจริงๆ
        try {
          await notifyAchievementUnlocked(userId, unlocked);
        } catch (notifyErr) {
          console.error('สร้างแจ้งเตือนปลดล็อกเหรียญไม่สำเร็จ:', notifyErr.message);
        }
      } catch (err) {
        // ชนกับ unique index = มีอีก request ปลดล็อกไปพร้อมกันพอดี ไม่ถือว่าพัง
        if (err.code !== 11000) throw err;
      }
    }
  }

  return newlyUnlocked;
};

module.exports = { MEDALS, TIERS, TIER_LABEL, tierKey, parseTierKey, getAchievements, syncAchievements };
