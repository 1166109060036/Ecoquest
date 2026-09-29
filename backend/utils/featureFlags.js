// สวิตช์เปิด/ปิดฟีเจอร์ทั้งระบบผ่าน env var — ปิดได้โดยไม่ต้องลบโค้ด
//
// SHOP_ENABLED — ร้านค้า (ซื้อไอเทม Energy/ของตกแต่ง, ซื้อ Upgrade Ability, ใช้ไอเทม Energy)
// อาจารย์ให้ตัดออกไปก่อน (28 ก.ย. 2026) → ไม่ตั้งค่า = ปิด, ตั้ง SHOP_ENABLED=true = เปิดกลับเหมือนเดิม
// ตอนปิด: ซื้อ/ใช้ไอเทมตอบ 403, Explore เห็นเควส solo ครบทุกอัน (Quest Unlock ซื้อไม่ได้แล้ว)
// ของที่ซื้อไปแล้วไม่ถูกยึดคืน (ของตกแต่งยังใส่ได้, upgrade เดิมยังคูณแต้มอยู่)
// ⚠️ ฝั่งแอพมี AppConstants.shopEnabled คู่กัน (ซ่อนปุ่ม/การ์ด) — เปิดกลับต้องเปิดทั้งสองที่
const shopEnabled = () => process.env.SHOP_ENABLED === 'true';

const SHOP_CLOSED_MESSAGE = 'The shop is closed';

module.exports = { shopEnabled, SHOP_CLOSED_MESSAGE };
