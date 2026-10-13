// จุดเดียวที่ validate + decode รูปแบบ base64 ที่แอพส่งมาเป็น JSON (ไม่ใช้ multer/multipart เพราะ
// ฝั่งแอพส่งเป็น base64 string ธรรมดาอยู่แล้ว) — ใช้ร่วมกันทั้งรูปโปรไฟล์ (routes/auth.js), รูปของในตู้เย็น
// (routes/fridgeItems.js) และรูปหลักฐานเควส/ปาร์ตี้ กันโค้ด validate ซ้ำกันหลายที่แล้วแก้ไม่ครบ
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png'];

// ชนิดรูปจริงจาก "magic bytes" ต้นไฟล์ (13 ต.ค. 2026 — เดิมเชื่อ contentType ที่แอพส่งมาอย่างเดียว ส่งข้อมูลสุ่ม
// มาก็ผ่านและได้แต้ม) คืน 'image/jpeg' / 'image/png' หรือ null ถ้าไม่ใช่รูปที่รับ
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const imageTypeOf = (buffer) => {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(PNG_SIGNATURE)) return 'image/png';
  return null;
};

// throw Error ที่มี .status ติดมาด้วย ให้ route เรียก catch แล้วตอบ res.status(err.status).json(...)
// ได้ตรงๆ โดยไม่ต้อง if-else ซ้ำที่ทุก call site
// คืน { data, contentType } — contentType เป็นชนิดจริงจากไฟล์ (แอพเดาจากนามสกุลไฟล์ อาจไม่ตรง) ให้ผู้เรียกเก็บค่านี้
const decodeImage = (base64, contentType, maxBytes) => {
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

  const actualType = imageTypeOf(buffer);
  if (!actualType) {
    const err = new Error('Invalid image data');
    err.status = 400;
    throw err;
  }

  return { data: buffer, contentType: actualType };
};

// header ของทุก route ที่เสิร์ฟรูปที่ผู้ใช้อัป — nosniff กัน browser เดาชนิดไฟล์เองแล้วตีความเป็นอย่างอื่น
const setImageHeaders = (res, contentType) => {
  res.set('Content-Type', contentType);
  res.set('X-Content-Type-Options', 'nosniff');
  res.set('Cache-Control', 'public, max-age=31536000, immutable');
};

module.exports = { ALLOWED_IMAGE_TYPES, imageTypeOf, decodeImage, setImageHeaders };
