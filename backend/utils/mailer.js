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

// purpose: 'reset' (ลืมรหัสผ่าน) / 'verify' (ยืนยันอีเมลตอนสมัคร) / 'org' (ส่งคำขอองค์กร) / 'admin' (admin 2FA)
const COPY = {
  reset: { subject: 'Your EcoQuest password reset code', action: 'a password reset' },
  verify: { subject: 'Verify your EcoQuest email', action: 'an EcoQuest account' },
  org: { subject: 'Confirm your EcoQuest organization request', action: 'an organization request' },
  admin: { subject: 'Your EcoQuest admin access code', action: 'admin access' },
};

// Render (free) บล็อก port SMTP ขาออก -> nodemailer ค้างจน Connection timeout (22 ต.ค. 2026)
// ตั้ง BREVO_API_KEY ไว้ = ส่งผ่าน Brevo HTTP API (port 443) แทน / ไม่ตั้ง = Gmail SMTP เดิม (ใช้ตอนรันบนเครื่อง)
// sender ต้องเป็นอีเมลที่ยืนยันไว้ใน Brevo แล้ว (ใช้ GMAIL_USER ตัวเดิม)
const sendViaBrevo = async ({ to, subject, text }) => {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': process.env.BREVO_API_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sender: { name: 'EcoQuest', email: process.env.GMAIL_USER },
      to: [{ email: to }],
      subject,
      textContent: text,
    }),
    signal: AbortSignal.timeout(15000), // ไม่ให้แอพหมุนรอนานแบบตอน SMTP ค้าง
  });
  if (!res.ok) throw new Error(`Brevo send failed: ${res.status} ${await res.text()}`);
};

const sendOtpEmail = async (to, otp, purpose = 'reset') => {
  const { subject, action } = COPY[purpose];
  const text = `Your OTP code is ${otp}\n\nThis code expires in 10 minutes.\nIf you did not request ${action}, please ignore this email.`;
  if (process.env.BREVO_API_KEY) return sendViaBrevo({ to, subject, text });

  await transporter.sendMail({
    from: `"EcoQuest" <${process.env.GMAIL_USER}>`,
    to,
    subject,
    text,
  });
};

module.exports = { sendOtpEmail };
