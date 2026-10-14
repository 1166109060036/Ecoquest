// QR เช็คอินอีเวนต์องค์กร (14 ต.ค. 2026) — องค์กรเปิด QR บนมือถือที่งาน ผู้เข้าร่วมสแกนแล้วได้แต้ม
// โค้ดเปลี่ยนทุก 30 วินาที (HMAC ของ eventId + ช่วงเวลา ด้วย JWT_SECRET แบบเดียวกับ utils/photoSign.js)
// ถ่ายรูป QR ส่งต่อให้เพื่อนที่ไม่ได้มางานสแกนทีหลังไม่ได้ — รับโค้ดของช่วงปัจจุบันกับช่วงก่อนหน้า (รวม ≤ 60 วิ)
// เผื่อเน็ตช้า/สแกนตอนโค้ดเพิ่งเปลี่ยน
const crypto = require('crypto');

const QR_WINDOW_MS = 30 * 1000;
const PREFIX = 'ecoquest-event';

const windowOf = (t) => Math.floor(t / QR_WINDOW_MS);

const codeFor = (eventId, w) =>
  crypto
    .createHmac('sha256', process.env.JWT_SECRET || '')
    .update(`orgqr:${eventId}:${w}`)
    .digest('base64url')
    .slice(0, 16);

// ข้อความที่อยู่ใน QR + อีกกี่ ms ต้องขอใหม่ (แอพตั้งเวลารีเฟรชตามนี้)
const qrFor = (eventId, now = Date.now()) => {
  const w = windowOf(now);
  return {
    payload: `${PREFIX}:${eventId}:${codeFor(eventId, w)}`,
    expiresInMs: (w + 1) * QR_WINDOW_MS - now,
  };
};

const sameCode = (a, b) => {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};

// คืน eventId ถ้าโค้ดถูกและยังไม่หมดอายุ / null ถ้าไม่ใช่ QR ของ EcoQuest / 'expired' ถ้าเป็น QR อีเวนต์แต่โค้ดเก่าหรือผิด
const parseQr = (text, now = Date.now()) => {
  if (typeof text !== 'string' || text.length > 200) return null;
  const parts = text.trim().split(':');
  if (parts.length !== 3 || parts[0] !== PREFIX || !/^[0-9a-f]{24}$/.test(parts[1])) return null;
  const [, eventId, code] = parts;
  const w = windowOf(now);
  if (sameCode(code, codeFor(eventId, w)) || sameCode(code, codeFor(eventId, w - 1))) return { eventId };
  return { eventId, expired: true };
};

module.exports = { qrFor, parseQr, QR_WINDOW_MS };
