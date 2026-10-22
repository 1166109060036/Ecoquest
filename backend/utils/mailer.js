const nodemailer = require('nodemailer');

// ส่งอีเมลผ่าน Gmail SMTP — ต้องตั้งค่า GMAIL_USER + GMAIL_APP_PASSWORD ใน .env
// GMAIL_APP_PASSWORD ต้องเป็น "App Password" ที่สร้างจาก Google Account (ต้องเปิด 2FA ก่อน)
// ห้ามใช้รหัสผ่าน Gmail ปกติ เพราะ Google บล็อกการ login แบบ SMTP ตรงๆ ด้วยรหัสผ่านจริง
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

// purpose: 'reset' (ลืมรหัสผ่าน) / 'verify' (ยืนยันอีเมลตอนสมัคร)
const COPY = {
  reset: { subject: 'Your EcoQuest password reset code', action: 'a password reset' },
  verify: { subject: 'Verify your EcoQuest email', action: 'an EcoQuest account' },
};

const sendOtpEmail = async (to, otp, purpose = 'reset') => {
  const { subject, action } = COPY[purpose];
  await transporter.sendMail({
    from: `"EcoQuest" <${process.env.GMAIL_USER}>`,
    to,
    subject,
    text: `Your OTP code is ${otp}\n\nThis code expires in 10 minutes.\nIf you did not request ${action}, please ignore this email.`,
  });
};

module.exports = { sendOtpEmail };
