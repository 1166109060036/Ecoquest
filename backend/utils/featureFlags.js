// สวิตช์เปิด/ปิดฟีเจอร์ทั้งระบบผ่าน env var — ปิดได้โดยไม่ต้องลบโค้ด
//
// SHOP_ENABLED — ร้านไอเทม (ซื้อ/ใช้ไอเทม Energy, ซื้อของตกแต่ง) + upgrade Quest Unlock
// อาจารย์ให้ตัดออกไปก่อน (28 ก.ย. 2026) → ไม่ตั้งค่า = ปิด, ตั้ง SHOP_ENABLED=true = เปิดกลับเหมือนเดิม
// ตอนปิด: ซื้อ/ใช้ไอเทมตอบ 403, Quest Unlock ถูกซ่อน/ซื้อไม่ได้ และ Explore เห็นเควส solo ครบทุกอัน
// ของที่ซื้อไปแล้วไม่ถูกยึดคืน (ของตกแต่งยังใส่ได้, upgrade เดิมยังคูณแต้มอยู่)
//
// UPGRADES_ENABLED — การ์ด Upgrade Ability (Point/XP/Party Booster) ใช้ Points ซื้อ
// ผู้ใช้ขอคืน (29 ก.ย. 2026) แยกจากร้านไอเทม → ไม่ตั้งค่า = เปิด, ตั้ง UPGRADES_ENABLED=false = ปิด
//
// ⚠️ ฝั่งแอพมี AppConstants.shopEnabled / upgradesEnabled คู่กัน (ซ่อนปุ่ม/การ์ด) — เปลี่ยนต้องเปลี่ยนทั้งสองที่
const shopEnabled = () => process.env.SHOP_ENABLED === 'true';
const upgradesEnabled = () => process.env.UPGRADES_ENABLED !== 'false';

// upgrade ที่ผูกกับร้าน — ร้านปิดแล้วซ่อน/ซื้อไม่ได้ (ทุกคนเห็นเควสครบอยู่แล้ว ซื้อไปก็ไม่มีผล)
const SHOP_ONLY_UPGRADES = ['quest_unlock'];

const SHOP_CLOSED_MESSAGE = 'The shop is closed';
const UPGRADES_CLOSED_MESSAGE = 'Upgrades are not available right now';

module.exports = {
  shopEnabled,
  upgradesEnabled,
  SHOP_ONLY_UPGRADES,
  SHOP_CLOSED_MESSAGE,
  UPGRADES_CLOSED_MESSAGE,
};
