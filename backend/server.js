require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');
const { seedQuests } = require('./scripts/seedQuests');
const authRoutes = require('./routes/auth');
const questRoutes = require('./routes/quests');
const fridgeItemRoutes = require('./routes/fridgeItems');
const achievementRoutes = require('./routes/achievements');
const partyRoutes = require('./routes/party');

const app = express();

// seed quest ตอน boot — upsert อิง title เลยรันซ้ำได้ ไม่สร้างของซ้ำ
// มีไว้เพราะบางเน็ต (เช่น wifi มหาลัย) ต่อ Atlas จากเครื่อง dev ไม่ได้ เลยรัน
// `npm run seed:quests` เองไม่ได้ — ให้ตัว server บน Render seed ให้แทน
// ปิดได้ด้วย env SEED_QUESTS_ON_BOOT=false
connectDB().then(async () => {
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
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/quests', questRoutes);
app.use('/api/fridge-items', fridgeItemRoutes);
app.use('/api/achievements', achievementRoutes);
app.use('/api/party', partyRoutes);

app.get('/', (req, res) => {
  res.send('EcoQuest API is running 🌱');
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
