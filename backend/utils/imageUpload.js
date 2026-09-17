// จุดเดียวที่ validate + decode รูปแบบ base64 ที่แอพส่งมาเป็น JSON (ไม่ใช้ multer/multipart เพราะ
// ฝั่งแอพส่งเป็น base64 string ธรรมดาอยู่แล้ว) — ใช้ร่วมกันทั้งรูปโปรไฟล์ (routes/auth.js) และรูปของใน
// ตู้เย็น (routes/fridgeItems.js) กันโค้ด validate ซ้ำกันสองที่แล้วแก้ไม่ครบ
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png'];

// throw Error ที่มี .status ติดมาด้วย ให้ route เรียก catch แล้วตอบ res.status(err.status).json(...)
// ได้ตรงๆ โดยไม่ต้อง if-else ซ้ำที่ทุก call site
const decodeImageBase64 = (base64, contentType, maxBytes) => {
  if (typeof base64 !== 'string' || !ALLOWED_IMAGE_TYPES.includes(contentType)) {
    const err = new Error('Invalid image data');
    err.status = 400;
    throw err;
  }

  const buffer = Buffer.from(base64, 'base64');
  if (buffer.length === 0 || buffer.length > maxBytes) {
    const err = new Error('Image is too large');
    err.status = 400;
    throw err;
  }

  return buffer;
};

module.exports = { ALLOWED_IMAGE_TYPES, decodeImageBase64 };
