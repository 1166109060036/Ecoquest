const express = require('express');
const mongoose = require('mongoose');
const FridgeItem = require('../models/FridgeItem');
const authMiddleware = require('../middleware/auth');
const { deleteExpiryNotifications } = require('../utils/notifications');
const { decodeImage, setImageHeaders } = require('../utils/imageUpload');
const { limitBy, byUser } = require('../utils/rateLimit');
const { photoSig, isValidPhotoSig } = require('../utils/photoSign');
const { purgeExpiredFridgePhotos } = require('../utils/fridgePhotos');

const router = express.Router();
router.param('id', require('../utils/idParam'));

// กันไฟล์ใหญ่ผิดปกติ — ฝั่งแอพย่อเหลือด้านยาวสุด 640px quality 70 (~50-100KB) อยู่แล้ว
const MAX_FRIDGE_PHOTO_BYTES = 2 * 1024 * 1024;
// ขอบเขตข้อมูลต่อครั้ง (13 ต.ค. 2026 — เดิมไม่จำกัด ส่งชื่อยาวมาก/ของเป็นพันชิ้นได้ = ถม Atlas ฟรี)
const MAX_ITEMS_PER_SAVE = 20;
const MAX_ITEM_NAME_LENGTH = 60;
const MAX_QUANTITY = 99;
const limitFridgeSaves = limitBy('fridge-save', { windowMs: 60 * 60 * 1000, max: 30 }, byUser,
  'You are saving very quickly. Please try again later');

const toClient = (item) => ({
  id: item._id,
  itemName: item.itemName,
  expirationDate: item.expirationDate,
  quantity: item.quantity,
  photoPath: item.photoPath,
  // ?s= ลายเซ็นกันคนอื่นเดา URL รูปในตู้เย็น (utils/photoSign.js)
  photoUrl: item.photoContentType ? `/fridge-items/${item._id}/photo?s=${photoSig('fridge', item._id)}` : null,
  photoRemoved: Boolean(item.photoRemovedAt),
  // แอพเรียงตาม "วันที่เพิ่ม" ได้ (อาจารย์ขอ 7 ต.ค. 2026) — ของเก่าที่ไม่มี addedAt ใช้ createdAt แทน
  addedAt: item.addedAt || item.createdAt || null,
});

// @route   GET /api/fridge-items
// @desc    ของในตู้เย็นทั้งหมดของ user คนนี้ (ใกล้หมดอายุที่สุดขึ้นก่อน)
router.get('/', authMiddleware, async (req, res) => {
  try {
    // -photoData กัน Buffer รูปถูกดึงมาทั้งลิสต์โดยไม่ได้ใช้ (แนวเดียวกับ User.avatarData) —
    // รูปจริงดึงทีหลังทีละรูปตอน Image.network ยิงไปที่ GET /:id/photo เอง
    // ลบรูปของที่หมดอายุของคนนี้ก่อนส่งลิสต์ (sweep รวมทั้ง server ใน utils/submissions.js อาจยังไม่ถึงรอบ)
    await purgeExpiredFridgePhotos({ userId: req.userId });
    const items = await FridgeItem.find({ userId: req.userId })
      .select('-photoData')
      .sort({ expirationDate: 1 });
    res.json({ items: items.map(toClient) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/fridge-items
// @desc    เพิ่มของเข้าตู้เย็น — รับได้ทีละหลายชิ้น เพราะผู้ใช้จะกด Finish ทีเดียวหลังเพิ่มครบ
// body: { items: [{ itemName, expirationDate, quantity, photoBase64, photoContentType }] }
router.post('/', authMiddleware, limitFridgeSaves, async (req, res) => {
  try {
    const { items } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'No items to add' });
    }
    if (items.length > MAX_ITEMS_PER_SAVE) {
      return res.status(400).json({ message: `You can save up to ${MAX_ITEMS_PER_SAVE} items at a time` });
    }

    const invalid = items.find(
      (i) => !i || typeof i.itemName !== 'string' || !i.itemName.trim() || !i.expirationDate
        || Number.isNaN(new Date(i.expirationDate).getTime())
    );
    if (invalid) {
      return res.status(400).json({ message: 'Each item needs a name and an expiration date' });
    }
    if (items.some((i) => i.itemName.trim().length > MAX_ITEM_NAME_LENGTH)) {
      return res.status(400).json({ message: `Item names must be ${MAX_ITEM_NAME_LENGTH} characters or fewer` });
    }
    const badQuantity = items.find(
      (i) => i.quantity !== undefined && i.quantity !== null
        && !(Number.isInteger(i.quantity) && i.quantity >= 1 && i.quantity <= MAX_QUANTITY)
    );
    if (badQuantity) {
      return res.status(400).json({ message: `Quantity must be a whole number from 1 to ${MAX_QUANTITY}` });
    }

    // decode รูปทุก item ก่อน insert จริง — item ไหนรูปพังก็ตอบ 400 ทั้ง request เลย ไม่ insert
    // บางส่วนค้างไว้ครึ่งๆ กลางๆ (เหมือนเช็ค name/expirationDate ด้านบนที่ทำก่อน insertMany เสมอ)
    const toInsert = [];
    for (const i of items) {
      let photoData = null;
      let photoContentType = null;
      if (i.photoBase64) {
        try {
          const image = decodeImage(i.photoBase64, i.photoContentType, MAX_FRIDGE_PHOTO_BYTES);
          photoData = image.data;
          photoContentType = image.contentType;
        } catch (err) {
          return res.status(err.status || 400).json({
            message: `${i.itemName}: ${err.message === 'Image is too large' ? 'Photo is too large' : 'Invalid photo data'}`,
          });
        }
      }

      toInsert.push({
        userId: req.userId,
        itemName: i.itemName.trim(),
        expirationDate: i.expirationDate,
        quantity: i.quantity || 1,
        photoData,
        photoContentType,
      });
    }

    const created = await FridgeItem.insertMany(toInsert);

    res.status(201).json({ items: created.map(toClient) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET /api/fridge-items/:id/photo
// @desc    เสิร์ฟรูปของในตู้เย็น — ไม่ต้อง login (Image.network ฝั่งแอพไม่แนบ token) แต่ต้องมี ?s= ลายเซ็นที่ได้จาก
//          photoUrl ใน GET /fridge-items (13 ต.ค. 2026 — เดิมรู้แค่ id ก็เปิดได้ และ ObjectId พอเดาได้)
router.get('/:id/photo', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid item id' });
    }

    if (!isValidPhotoSig('fridge', req.params.id, req.query.s)) {
      return res.status(404).json({ message: 'Photo not found' });
    }
    const item = await FridgeItem.findById(req.params.id).select('photoData photoContentType');
    if (!item || !item.photoData) {
      return res.status(404).json({ message: 'Photo not found' });
    }

    setImageHeaders(res, item.photoContentType);
    res.send(item.photoData);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE /api/fridge-items/:id
// @desc    ลบของออกจากตู้เย็น (เช่น กินหมดแล้ว หรือทิ้งไปแล้ว)
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    // ใส่ userId ในเงื่อนไขด้วย กันลบของคนอื่นด้วยการเดา id
    const deleted = await FridgeItem.findOneAndDelete({
      _id: req.params.id,
      userId: req.userId,
    });

    if (!deleted) {
      return res.status(404).json({ message: 'Item not found' });
    }

    // เอาของออกจากตู้เย็นแล้ว ไม่ควรค้างเตือนถึงของที่กินไปแล้ว
    await deleteExpiryNotifications(req.userId, deleted._id);

    res.json({ message: 'Item removed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
