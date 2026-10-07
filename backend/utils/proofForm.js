// ฟอร์มเก็บข้อมูลเพิ่มตอนส่งรูปหลักฐาน (ผู้ใช้สั่ง 7 ต.ค. 2026 — เควส "Return Containers to the Store" จากข่าว 6 ต.ค. 2026)
// เควสไหนตั้ง Quest.proofForm ไว้ แผ่นถ่ายรูปในแอพจะมีช่องให้เลือก/กรอกเพิ่ม แล้วเก็บไว้ใน QuestSubmission.details
// (ผู้ตรวจเห็นในหน้า Quest Review / ฟีด) — เควสที่ไม่ตั้งไว้ทำงานเหมือนเดิมทุกอย่าง
//
// รูปแบบ Quest.proofForm (ทุกช่องไม่บังคับ — ตั้งเฉพาะที่อยากเก็บ):
//   { choiceLabel, choices: [String] (เลือกได้หลายอัน ต้องเลือกอย่างน้อย 1),
//     countLabel, countMax (จำนวนชิ้น 1..countMax ต้องกรอก),
//     placeLabel (ข้อความสั้น ไม่บังคับ เช่น ชื่อร้าน) }
const PLACE_MAX = 60;

// ตรวจคำตอบจากแอพ (req.body.proofDetails) เทียบกับฟอร์มของเควส
// คืน { details } (null ถ้าเควสไม่มีฟอร์ม) หรือ { error } ข้อความภาษาอังกฤษให้แอพโชว์
const validateProofDetails = (form, raw) => {
  if (!form) return { details: null };
  const input = raw && typeof raw === 'object' ? raw : {};
  const details = {};

  if (Array.isArray(form.choices) && form.choices.length) {
    const picked = Array.isArray(input.choices) ? [...new Set(input.choices.map(String))] : [];
    const valid = picked.filter((c) => form.choices.includes(c));
    if (!valid.length) return { error: form.choiceLabel ? `${form.choiceLabel} — pick at least one` : 'Pick at least one option' };
    details.choices = valid;
  }

  if (form.countMax) {
    const count = Number(input.count);
    if (!Number.isInteger(count) || count < 1 || count > form.countMax) {
      return { error: `Enter how many items (1–${form.countMax})` };
    }
    details.count = count;
  }

  if (form.placeLabel && typeof input.place === 'string') {
    const place = input.place.trim().replace(/\s+/g, ' ').slice(0, PLACE_MAX);
    if (place) details.place = place;
  }

  return { details };
};

module.exports = { validateProofDetails, PLACE_MAX };
