const { initializeApp, cert } = require('firebase-admin/app');
const { getMessaging: getFcm } = require('firebase-admin/messaging');
const User = require('../models/User');

// ส่ง push notification ผ่าน Firebase Cloud Messaging (FCM) — เด้งบนหน้าจอโทรศัพท์แม้ปิดแอพอยู่
//
// ต้องตั้ง env FIREBASE_SERVICE_ACCOUNT = เนื้อหาไฟล์ service account JSON ทั้งก้อน (Firebase Console →
// Project settings → Service accounts → Generate new private key) ใส่เป็น JSON ตรงๆ หรือ base64 ก็ได้
// ⚠️ ห้าม commit ไฟล์นั้นลง git — ใส่ที่หน้า Environment ของ Render เท่านั้น
// ไม่ได้ตั้ง = push ปิดเงียบๆ (แจ้งเตือนในแอพยังทำงานปกติ) จะได้รัน backend บนเครื่อง dev ได้โดยไม่ต้องมี key
//
// เป้าหมายการส่งเป็น Firebase Installation ID (FID) ไม่ใช่ registration token แบบเก่า — firebase_messaging 17
// เลิกใช้ getToken() แล้ว แอพส่ง FID มาจาก onRegistered แทน (lib/services/push_service.dart)

let messaging; // undefined = ยังไม่ได้ลอง init, null = ใช้ไม่ได้
const MAX_PUSH_IDS_PER_USER = 10;

const getMessaging = () => {
  if (messaging !== undefined) return messaging;
  messaging = null;

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) {
    console.log('[push] FIREBASE_SERVICE_ACCOUNT not set — push notifications disabled');
    return messaging;
  }
  try {
    const json = raw.trim().startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
    initializeApp({ credential: cert(JSON.parse(json)) });
    messaging = getFcm();
    console.log('[push] Firebase initialized');
  } catch (err) {
    console.error('[push] Invalid FIREBASE_SERVICE_ACCOUNT — push notifications disabled:', err.message);
  }
  return messaging;
};

// จำ FID ของเครื่องนี้ให้ user — ดึง FID เดียวกันออกจากบัญชีอื่นก่อน (เครื่องเดียว logout แล้ว login บัญชีใหม่
// อาจได้ FID เดิม ไม่งั้นแจ้งเตือนของบัญชีเก่าจะเด้งเข้าเครื่องคนอื่น) เก็บไม่เกิน 10 เครื่องล่าสุด
const registerPushId = async (userId, fid) => {
  await User.updateMany({ _id: { $ne: userId }, pushIds: fid }, { $pull: { pushIds: fid } });
  await User.updateOne({ _id: userId }, { $pull: { pushIds: fid } });
  await User.updateOne(
    { _id: userId },
    { $push: { pushIds: { $each: [fid], $slice: -MAX_PUSH_IDS_PER_USER } } }
  );
  console.log(`[push] registered device for user ${userId}`);
};

const unregisterPushId = async (userId, fid) => {
  await User.updateOne({ _id: userId }, { $pull: { pushIds: fid } });
};

// FCM ตอบแบบนี้ = แอพถูกถอน/ล้างข้อมูล/logout ไปแล้ว ส่งต่อไปก็ไม่มีวันถึง ลบทิ้งได้เลย
// (ไม่นับ invalid-argument เพราะอาจเป็นที่ payload ของเราเอง ลบทิ้งจะทำให้ทุกเครื่องหลุดหมด)
// firebase-admin 14 ส่ง code มาแบบไม่มี prefix "messaging/" แล้ว
const DEAD_TARGET_CODES = new Set([
  'installation-id-not-registered',
  'registration-token-not-registered',
]);

// ส่ง push ไปทุกเครื่องของ user — ไม่ throw เด็ดขาด (push ส่งไม่ได้ต้องไม่ทำให้ request หลักพัง)
// data ส่งได้แต่ string เท่านั้น (ข้อจำกัดของ FCM)
const sendPush = async (userId, { title, body, data = {} }) => {
  try {
    const fcm = getMessaging();
    if (!fcm) return;

    const user = await User.findById(userId).select('+pushIds');
    const fids = user?.pushIds ?? [];
    if (fids.length === 0) {
      console.log(`[push] user ${userId} has no registered device — skipped`);
      return;
    }

    const stringData = Object.fromEntries(
      Object.entries(data).filter(([, v]) => v != null).map(([k, v]) => [k, String(v)])
    );
    const result = await fcm.sendEachForMulticast({
      fids,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: { color: '#2E7D32' },
      },
    });

    // FCM ปฏิเสธเป็นรายเครื่องไม่ throw — log ไว้ ไม่งั้นส่งไม่ถึงแล้วเงียบ
    result.responses.forEach((r, i) => {
      if (!r.success) console.error(`[push] device ${fids[i].slice(0, 8)}… rejected: ${r.error?.code} ${r.error?.message}`);
    });
    console.log(`[push] sent to user ${userId}: ${result.successCount}/${fids.length} devices`);

    const dead = fids.filter(
      (_, i) => !result.responses[i].success && DEAD_TARGET_CODES.has(result.responses[i].error?.code)
    );
    if (dead.length > 0) {
      await User.updateOne({ _id: userId }, { $pull: { pushIds: { $in: dead } } });
    }
  } catch (err) {
    console.error('[push] send failed:', err.message);
  }
};

module.exports = { sendPush, registerPushId, unregisterPushId };
