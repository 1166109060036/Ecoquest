// เช็คคำแปลภาษาญี่ปุ่นฝั่ง server (ไม่ต่อ DB): node scripts/checkI18n.js
// - ข้อความเควส/ไอเทม/อัปเกรด/เหรียญทุกตัวต้องมีคำแปล
// - ตัวอย่างข้อความแจ้งเตือน/ข้อความ error ที่ประกอบจากตัวแปรต้องแปลออกมาถูก
const assert = require('assert');
const { translateText, translateBody } = require('../utils/i18n');
const { QUESTS } = require('./seedQuests');
const { ITEMS } = require('../utils/inventory');
const { MEDALS, TIER_LABEL } = require('../utils/achievements');
const { UPGRADES } = require('../utils/upgrades');

const ja = (s) => translateText(s, 'ja');
const missing = [];
const need = (s) => s && ja(s) === s && missing.push(s);
for (const q of QUESTS) {
  ['title', 'description', 'detail', 'location', 'impactCategory'].forEach((f) => need(q[f]));
  if (q.proofForm) ['choiceLabel', 'countLabel', 'placeLabel'].forEach((f) => need(q.proofForm[f]));
}
ITEMS.forEach((i) => [i.title, i.description].forEach(need));
MEDALS.forEach((m) => need(m.title));
Object.values(TIER_LABEL).forEach(need);
UPGRADES.forEach((u) => [u.title, u.description].forEach(need));
assert.deepStrictEqual(missing, [], 'missing Japanese translations');

const cases = [
  ['Finish Your Meal · +12 points', '食事を残さず食べる · +12 ポイント'],
  ['Recycling — Complete 10 recycling quests', 'リサイクル — リサイクルのクエストを10回完了'],
  ['Sort Waste Correctly · +10 points, +12 XP (combo ×1.25)', 'ゴミを正しく分別する · +10 ポイント、+12 XP（コンボ ×1.25）'],
  ['Display name must be 20 characters or fewer', '表示名は20文字以内にしてください'],
  ['koo sent you a friend request', 'koo さんから友達申請が届きました'],
  ['user typed text', 'user typed text'],
];
for (const [en, expected] of cases) assert.strictEqual(ja(en), expected);
assert.strictEqual(translateText('Finish Your Meal', 'en'), 'Finish Your Meal');

// ฟิลด์ที่แอพส่งกลับมา (choices) / ใช้เทียบ (category) ต้องไม่ถูกแปล
const body = translateBody(
  { message: 'Quest started', quest: { title: 'Finish Your Meal', category: 'food_waste', proofForm: { choices: ['Food trays'] } } },
  'ja'
);
assert.strictEqual(body.message, 'クエストを開始しました');
assert.strictEqual(body.quest.category, 'food_waste');
assert.deepStrictEqual(body.quest.proofForm.choices, ['Food trays']);

console.log('i18n OK');
