require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const connectDB = require('./config/db');
const { seedQuests } = require('./scripts/seedQuests');
const PartyMember = require('./models/PartyMember');
const authRoutes = require('./routes/auth');
const questRoutes = require('./routes/quests');
const fridgeItemRoutes = require('./routes/fridgeItems');
const achievementRoutes = require('./routes/achievements');
const partyRoutes = require('./routes/party');
const userRoutes = require('./routes/users');
const inventoryRoutes = require('./routes/inventory');
const notificationRoutes = require('./routes/notifications');
const friendRoutes = require('./routes/friends');
const chatRoutes = require('./routes/chat');
const upgradeRoutes = require('./routes/upgrades');
const adminRoutes = require('./routes/admin');
const { initSocket } = require('./sockets');

const app = express();
// ต้องมี http.createServer(app) แยกออกมาจาก app เอง เพื่อให้ socket.io attach ตัวเองเข้ากับ
// HTTP server ตัวเดียวกันได้ (แต่ก่อนใช้ app.listen(...) ตรงๆ ซึ่งไม่มี handle ให้ socket.io เกาะ)
const server = http.createServer(app);
// cors: origin: '*' ให้ตรงกับ app.use(cors()) ของ REST ด้านล่าง (permissive เหมือนกัน ไม่ได้เข้มกว่า/
// หลวมกว่ากัน)
const io = new Server(server, { cors: { origin: '*' } });
initSocket(io);

// seed quest ตอน boot — upsert อิง title เลยรันซ้ำได้ ไม่สร้างของซ้ำ
// มีไว้เพราะบางเน็ต (เช่น wifi มหาลัย) ต่อ Atlas จากเครื่อง dev ไม่ได้ เลยรัน
// `npm run seed:quests` เองไม่ได้ — ให้ตัว server บน Render seed ให้แทน
// ปิดได้ด้วย env SEED_QUESTS_ON_BOOT=false
connectDB().then(async () => {
  // ล้าง PartyMember รุ่นเก่าที่ผูกกับ questId ตรงๆ (ก่อนจะมีห้อง/Party แยกออกมา)
  // เขียนเป็น idempotent เพราะรันซ้ำทุกครั้งที่ Render restart ก็ไม่มีผลเสีย
  try {
    const { deletedCount } = await PartyMember.deleteMany({ partyId: { $exists: false } });
    if (deletedCount > 0) {
      console.log(`🧹 ล้าง PartyMember รุ่นเก่าทิ้ง ${deletedCount} แถว`);
    }
  } catch (err) {
    console.error('⚠️  ล้าง PartyMember รุ่นเก่าไม่สำเร็จ:', err.message);
  }

  if (process.env.SEED_QUESTS_ON_BOOT === 'false') return;
  try {
    const active = await seedQuests({ verbose: false });
    console.log(`🌱 seed quest แล้ว (เปิดใช้งานอยู่ ${active} quest)`);
  } catch (err) {
    // seed พังไม่ควรทำให้ API ทั้งตัวล่ม — quest เดิมใน DB ยังใช้ได้อยู่
    console.error('⚠️  seed quest ตอน boot ไม่สำเร็จ:', err.message);
  }
});

app.use(cors());
// limit ปกติของ express.json คือ 100kb — รูปโปรไฟล์ที่ส่งมาเป็น base64 ใน body เกินแน่ๆ
// (base64 กินพื้นที่มากกว่าไฟล์จริง ~33% ยิ่งบวก JSON overhead) เลยขยับเป็น 6mb ให้พอ
// แต่ไม่ปล่อยไม่จำกัดไปเลย กันคนส่ง payload ใหญ่ผิดปกติมาถล่ม server
app.use(express.json({ limit: '6mb' }));

app.use('/api/auth', authRoutes);
app.use('/api/quests', questRoutes);
app.use('/api/fridge-items', fridgeItemRoutes);
app.use('/api/achievements', achievementRoutes);
app.use('/api/party', partyRoutes);
app.use('/api/users', userRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/upgrades', upgradeRoutes);
// dev/QA เท่านั้น — เข้าได้เฉพาะอีเมลใน ADMIN_EMAILS (ดู middleware/admin.js), ปิดโดย default ถ้าไม่ตั้งค่า
app.use('/api/admin', adminRoutes);

app.get('/', (req, res) => {
  res.send('EcoQuest API is running 🌱');
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
