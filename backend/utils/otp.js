const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { limiter, tooMany } = require('./rateLimit');

// OTP ทางอีเมลที่ใช้ร่วมกันทุก flow (ย้ายออกมาจาก routes/auth.js 22 ต.ค. 2026 ให้ org/admin ใช้ด้วย):
//   prefix 'reset'  -> ลืมรหัสผ่าน (User.resetOtp*)
//   prefix 'verify' -> ยืนยันอีเมลตอนสมัคร / upgrade guest / ยืนยันก่อนส่งคำขอองค์กร / admin 2FA (User.verifyOtp*)
//                      ใช้ชุดฟิลด์เดียวกันได้เพราะทุกอันส่งไปอีเมลเดียวกันของบัญชีนั้น — ขอ OTP ใหม่ = อันเก่าใช้ไม่ได้

const OTP_TTL_MS = 10 * 60 * 1000; // OTP หมดอายุใน 10 นาที
// crypto.randomInt แทน Math.random (เดาได้ง่ายกว่า) — 6 หลัก 100000-999999
const generateOtp = () => crypto.randomInt(100000, 1000000).toString();
// กรอก OTP ผิดเกินนี้ = OTP นั้นใช้ไม่ได้ ต้องขอใหม่ (13 ต.ค. 2026 — เดิมเดาได้ไม่จำกัด = เข้าบัญชีใครก็ได้ที่รู้อีเมล)
const MAX_OTP_ATTEMPTS = 5;

// ตั้ง OTP ใหม่ลง user (caller ต้อง save เอง) แล้วคืน OTP ตัวจริงไว้ส่งอีเมล
const issueOtp = async (user, prefix) => {
  const otp = generateOtp();
  user[`${prefix}OtpHash`] = await bcrypt.hash(otp, await bcrypt.genSalt(10));
  user[`${prefix}OtpExpires`] = new Date(Date.now() + OTP_TTL_MS);
  user[`${prefix}OtpAttempts`] = 0;
  return otp;
};

// คืน null = OTP ถูก (ล้าง OTP ใน user แล้ว ใช้ได้ครั้งเดียว — caller ต้อง save) / string = ข้อความ error
const checkOtp = async (user, prefix, otp) => {
  const hashKey = `${prefix}OtpHash`;
  const expiresKey = `${prefix}OtpExpires`;
  const attemptsKey = `${prefix}OtpAttempts`;
  if (!user[hashKey] || !user[expiresKey] || user[expiresKey] < new Date()) {
    return 'Invalid or expired OTP';
  }

  if (!(await bcrypt.compare(String(otp), user[hashKey]))) {
    // นับครั้งที่ผิดแบบ atomic ($inc) — ครบ MAX_OTP_ATTEMPTS ล้าง OTP ทิ้ง ต้องขอใหม่ (ขอใหม่ได้นาทีละครั้ง)
    const updated = await User.findOneAndUpdate(
      { _id: user._id, [hashKey]: user[hashKey] },
      { $inc: { [attemptsKey]: 1 } },
      { new: true, projection: { [attemptsKey]: 1 } }
    );
    if (updated && updated[attemptsKey] >= MAX_OTP_ATTEMPTS) {
      await User.updateOne(
        { _id: user._id },
        { $set: { [hashKey]: null, [expiresKey]: null, [attemptsKey]: 0 } }
      );
      return 'Too many wrong codes. Please request a new OTP';
    }
    return 'Invalid or expired OTP';
  }

  user[hashKey] = null;
  user[expiresKey] = null;
  user[attemptsKey] = 0;
  return null;
};

const otpSendMinute = limiter('otp-send-1m', { windowMs: 60 * 1000, max: 1 }); // ขอ OTP ต่ออีเมล
const otpSendHour = limiter('otp-send-1h', { windowMs: 60 * 60 * 1000, max: 5 });

// ขอ OTP ได้นาทีละครั้ง / ชั่วโมงละ 5 ครั้งต่ออีเมล (ทุก flow รวมกัน) — คืน true = ตอบ 429 ไปแล้ว
const otpSendBlocked = (res, emailKey) => {
  if (otpSendMinute.blocked(emailKey) || otpSendHour.blocked(emailKey)) {
    const wait = otpSendHour.blocked(emailKey) ? otpSendHour.retryAfter(emailKey) : otpSendMinute.retryAfter(emailKey);
    tooMany(res, wait, 'Please wait a moment before requesting another OTP');
    return true;
  }
  otpSendMinute.hit(emailKey);
  otpSendHour.hit(emailKey);
  return false;
};

module.exports = { issueOtp, checkOtp, otpSendBlocked };
