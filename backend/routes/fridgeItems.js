const express = require('express');
const mongoose = require('mongoose');
const FridgeItem = require('../models/FridgeItem');
const authMiddleware = require('../middleware/auth');
const { deleteExpiryNotifications } = require('../utils/notifications');
const { decodeImageBase64 } = require('../utils/imageUpload');

const router = express.Router();

// กันไฟล์ใหญ่ผิดปกติ — ค่าเดียวกับ avatar (ฝั่งแอพย่อเหลือ maxWidth 1200/quality 85 อยู่แล้ว)
const MAX_FRIDGE_PHOTO_BYTES = 4 * 1024 * 1024;

const toClient = (item) => ({
  id: item._id,
  itemName: item.itemName,
  expirationDate: item.expirationDate,
  quantity: item.quantity,
  photoPath: item.photoPath,
  photoUrl: item.photoContentType ? `/fridge-items/${item._id}/photo` : null,
});

// @route   GET /api/fridge-items
// @desc    ของในตู้เย็นทั้งหมดของ user คนนี้ (ใกล้หมดอายุที่สุดขึ้นก่อน)
router.get('/', authMiddleware, async (req, res) => {
  try {
    // -photoData กัน Buffer รูปถูกดึงมาทั้งลิสต์โดยไม่ได้ใช้ (แนวเดียวกับ User.avatarData) —
    // รูปจริงดึงทีหลังทีละรูปตอน Image.network ยิงไปที่ GET /:id/photo เอง
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
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { items } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'No items to add' });
    }

    const invalid = items.find((i) => !i || !i.itemName || !i.expirationDate);
    if (invalid) {
      return res.status(400).json({ message: 'Each item needs a name and an expiration date' });
    }

    // decode รูปทุก item ก่อน insert จริง — item ไหนรูปพังก็ตอบ 400 ทั้ง request เลย ไม่ insert
    // บางส่วนค้างไว้ครึ่งๆ กลางๆ (เหมือนเช็ค name/expirationDate ด้านบนที่ทำก่อน insertMany เสมอ)
    const toInsert = [];
    for (const i of items) {
      let photoData = null;
      let photoContentType = null;
      if (i.photoBase64) {
        try {
          photoData = decodeImageBase64(i.photoBase64, i.photoContentType, MAX_FRIDGE_PHOTO_BYTES);
          photoContentType = i.photoContentType;
        } catch (err) {
          return res.status(err.status || 400).json({
            message: `${i.itemName}: ${err.message === 'Image is too large' ? 'Photo is too large' : 'Invalid photo data'}`,
          });
        }
      }

      toInsert.push({
        userId: req.userId,
        itemName: i.itemName,
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
// @desc    เสิร์ฟรูปของในตู้เย็น — public ไม่ต้อง login (แนวเดียวกับ GET /api/users/:id/avatar)
//          ObjectId ทายไม่ได้จริง และของในตู้เย็นไม่ใช่ข้อมูลอ่อนไหว เลยเลือกความง่ายแบบเดียวกับ avatar
router.get('/:id/photo', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'Invalid item id' });
    }

    const item = await FridgeItem.findById(req.params.id).select('photoData photoContentType');
    if (!item || !item.photoData) {
      return res.status(404).json({ message: 'Photo not found' });
    }

    res.set('Content-Type', item.photoContentType);
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
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
