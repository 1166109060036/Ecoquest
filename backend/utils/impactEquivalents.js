// ค่าเทียบผลกระทบ (kgCO2e -> สิ่งที่คนเข้าใจง่าย) ใช้ในการ์ด "Ebetsu's impact" ของฟีดชุมชน (routes/impact.js)
// ที่มาของทุกค่าอยู่ใน CO2_RESEARCH.md หัวข้อ "ค่าเทียบผลกระทบ" — ห้ามเพิ่มค่าที่ไม่มีแหล่งอ้างอิง
//
// ต้นสน (スギ) อายุ 36-40 ปี ในป่าปลูกที่ดูแลดี ดูดซับ CO2 ~8.8 kg/ต้น/ปี (林野庁 — 8.8 ตัน/ha/ปี ÷ 1,000 ต้น/ha)
// https://www.rinya.maff.go.jp/j/sin_riyou/ondanka/20141113_topics2_2.html
const CEDAR_KG_PER_TREE_PER_YEAR = 8.8;

// แปลงเป็น "ต้นสนกี่ต้นดูดซับใน 1 ปี" และ "ต้นสน 1 ต้นใช้เวลากี่วัน" — แอพเลือกโชว์แบบที่อ่านง่ายกว่า
// (ยอดน้อยโชว์เป็นวัน ยอดเยอะโชว์เป็นจำนวนต้น)
const equivalentsFor = (co2eKg) => ({
  cedarTreeYears: Math.round((co2eKg / CEDAR_KG_PER_TREE_PER_YEAR) * 10) / 10,
  cedarTreeDays: Math.round((co2eKg / CEDAR_KG_PER_TREE_PER_YEAR) * 365),
});

module.exports = { CEDAR_KG_PER_TREE_PER_YEAR, equivalentsFor };
