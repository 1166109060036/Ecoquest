const express = require('express');
const FridgeItem = require('../models/FridgeItem');
const authMiddleware = require('../middleware/auth');
const { deleteExpiryNotifications } = require('../utils/notifications');

const router = express.Router();

const toClient = (item) => ({
  id: item._id,
  itemName: item.itemName,
  expirationDate: item.expirationDate,
  quantity: item.quantity,
  photoPath: item.photoPath,
});

// @route   GET /api/fridge-items
// @desc    ของในตู้เย็นทั้งหมดของ user คนนี้ (ใกล้หมดอายุที่สุดขึ้นก่อน)
router.get('/', authMiddleware, async (req, res) => {
  try {
    const items = await FridgeItem.find({ userId: req.userId }).sort({ expirationDate: 1 });
    res.json({ items: items.map(toClient) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST /api/fridge-items
// @desc    เพิ่มของเข้าตู้เย็น — รับได้ทีละหลายชิ้น เพราะผู้ใช้จะกด Finish ทีเดียวหลังเพิ่มครบ
// body: { items: [{ itemName, expirationDate, quantity, photoPath }] }
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

    const created = await FridgeItem.insertMany(
      items.map((i) => ({
        userId: req.userId,
        itemName: i.itemName,
        expirationDate: i.expirationDate,
        quantity: i.quantity || 1,
        photoPath: i.photoPath || null,
      }))
    );

    res.status(201).json({ items: created.map(toClient) });
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
