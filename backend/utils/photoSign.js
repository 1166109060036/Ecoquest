// ลายเซ็นใน URL รูปที่เสิร์ฟแบบไม่ต้อง login (13 ต.ค. 2026) — เดิมรู้แค่ id ก็เปิดรูปได้ และ ObjectId เรียงตามเวลา+ตัวนับ
// พอเดาได้ = ไล่ดูรูปในตู้เย็นของคนอื่น / รูปหลักฐานที่ถูกซ่อนได้ ตอนนี้ URL ต้องมี ?s= ที่ server สร้างจาก JWT_SECRET
// แอพไม่ต้องแก้ เพราะใช้ photoUrl ที่ server ส่งมาเสมอ (รูปโปรไฟล์ยังเปิดตรงๆ ได้เหมือนเดิม — ไม่ใช่ข้อมูลส่วนตัว)
const crypto = require('crypto');

const photoSig = (kind, id) =>
  crypto
    .createHmac('sha256', process.env.JWT_SECRET || '')
    .update(`${kind}:${id}`)
    .digest('base64url')
    .slice(0, 22);

// เทียบแบบเวลาคงที่ (timingSafeEqual) — คืน false ถ้าไม่มี/ไม่ตรง
const isValidPhotoSig = (kind, id, sig) => {
  if (typeof sig !== 'string') return false;
  const expected = Buffer.from(photoSig(kind, id));
  const given = Buffer.from(sig);
  return expected.length === given.length && crypto.timingSafeEqual(expected, given);
};

module.exports = { photoSig, isValidPhotoSig };
