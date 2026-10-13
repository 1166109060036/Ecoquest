// จำกัดจำนวน request ในหน่วยความจำ (13 ต.ค. 2026) — เดิมไม่มีเลย: เดารหัสผ่าน/OTP ได้ไม่จำกัด, สร้าง guest
// ไม่จำกัด, อัปรูปจน Atlas ฟรี 512MB เต็มได้ ไม่ใช้ package เพิ่ม — Render รัน instance เดียว เก็บใน Map พอ
// (restart แล้วตัวนับหาย ยอมรับได้) ถ้าวันหนึ่ง scale หลาย instance ต้องย้ายไป Redis
//
// แบบ fixed window: key เดิมนับได้ไม่เกิน max ครั้งใน windowMs นับจากครั้งแรกของรอบ
const buckets = new Map(); // `${name}:${key}` -> { count, resetAt }

// ล้างรอบที่หมดอายุทุก 10 นาที กัน Map โตไม่หยุด — unref ไม่ให้ค้าง process ตอนปิด
setInterval(() => {
  const now = Date.now();
  for (const [k, b] of buckets) if (b.resetAt <= now) buckets.delete(k);
}, 10 * 60 * 1000).unref();

const limiter = (name, { windowMs, max }) => {
  const bucketOf = (key) => {
    const k = `${name}:${key}`;
    const now = Date.now();
    let b = buckets.get(k);
    if (!b || b.resetAt <= now) {
      b = { count: 0, resetAt: now + windowMs };
      buckets.set(k, b);
    }
    return b;
  };
  return {
    // นับ 1 ครั้ง — คืน true ถ้ายังไม่เกิน
    hit(key) {
      const b = bucketOf(key);
      b.count += 1;
      return b.count <= max;
    },
    // เกินแล้วหรือยัง (ไม่นับเพิ่ม) — ใช้กับ "นับเฉพาะครั้งที่ผิด" เช่นล็อกอินผิด
    blocked(key) {
      return bucketOf(key).count >= max;
    },
    reset(key) {
      buckets.delete(`${name}:${key}`);
    },
    // วินาทีที่ต้องรอ (สำหรับข้อความบอกผู้ใช้)
    retryAfter(key) {
      const b = buckets.get(`${name}:${key}`);
      return b ? Math.max(1, Math.ceil((b.resetAt - Date.now()) / 1000)) : 0;
    },
  };
};

const tooMany = (res, seconds, message = 'Too many requests. Please try again later') => {
  if (seconds) res.set('Retry-After', String(seconds));
  return res.status(429).json({ message });
};

// middleware: นับทุก request ตาม keyFn(req) (เช่น IP หรือ userId) — เกิน = 429
const limitBy = (name, opts, keyFn, message) => {
  const l = limiter(name, opts);
  return (req, res, next) => {
    const key = keyFn(req);
    if (!l.hit(key)) return tooMany(res, l.retryAfter(key), message);
    next();
  };
};

const byIp = (req) => req.ip || 'unknown';
const byUser = (req) => String(req.userId || req.ip || 'unknown');

module.exports = { limiter, limitBy, tooMany, byIp, byUser };
