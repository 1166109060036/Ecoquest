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

module.exports = { avatarUrlFor };
