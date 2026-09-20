// รวม logic สร้าง URL รูปโปรไฟล์ไว้ที่เดียว — ทุกจุดที่ต้องส่ง avatarUrl กลับไปให้แอพ
// (GET /auth/me, GET /users/:id, รายชื่อสมาชิกปาร์ตี้ใน routes/party.js) ต้องเรียกจากที่นี่
// ให้ได้ path แบบเดียวกันเป๊ะๆ
//
// รูปโปรไฟล์เก็บเป็น Buffer ในฐานข้อมูลจริงแล้ว (ไม่ใช่ path ในเครื่องเหมือนเดิม)
// เสิร์ฟผ่าน GET /api/users/:id/avatar — ดู routes/users.js
//
// query string ?v=<timestamp> ใช้กัน cache รูปเก่าค้างฝั่งแอพ (Flutter cache รูปตาม URL
// ถ้า URL เดิมทุกครั้งแต่เปลี่ยนรูปใหม่ แอพจะยังโชว์รูปเก่าที่ cache ไว้อยู่ ต้องเปลี่ยน query
// string ทุกครั้งที่รูปเปลี่ยนจริง — ใช้เวลาที่อัปเดตล่าสุดเป็นค่านั้นเลย ง่ายและแม่นยำพอ)
const avatarUrlFor = (user) => {
  if (!user.avatarContentType) return null;
  const version = user.avatarUpdatedAt ? user.avatarUpdatedAt.getTime() : 0;
  return `/users/${user._id}/avatar?v=${version}`;
};

// ของตกแต่งโปรไฟล์ที่ user คนนี้ใส่อยู่ — เรียกคู่กับ avatarUrlFor เสมอทุกจุดที่ต้องโชว์ตัวตนของ
// user ให้คนอื่นเห็น (GET /auth/me, GET /users/:id, สมาชิกปาร์ตี้, รายชื่อเพื่อน) ต้อง .select('cosmetics')
// หรือ .populate(... 'cosmetics') มาด้วยเสมอ ไม่งั้นจะได้ undefined ทุกช่องเงียบๆ ไม่ throw
const cosmeticsFor = (user) => ({
  frame: user.cosmetics?.frame ?? null,
  nameStyle: user.cosmetics?.nameStyle ?? null,
  background: user.cosmetics?.background ?? null,
  effect: user.cosmetics?.effect ?? null,
});

module.exports = { avatarUrlFor, cosmeticsFor };
