# EcoQuest — Project Context (อ่านก่อนเริ่มทำงานต่อ)

> ไฟล์นี้สรุปทุกอย่างที่คุยกันไว้ตอนออกแบบ/สร้างโปรเจคนี้กับ Claude (แชท) ก่อนจะย้ายมาทำต่อใน Claude Code
> ไม่มีข้อมูลนี้อยู่ในบทสนทนาอื่น — ถ้าจะทำอะไรที่ขัดกับสิ่งที่เขียนไว้ในนี้ ให้ถามผู้ใช้ก่อน

## 1. โปรเจคนี้คืออะไร

**EcoQuest** คือแอป gamification ด้านสิ่งแวดล้อม สำหรับผู้อยู่อาศัยใน Ebetsu City, Hokkaido
แนวคิดหลัก: **Start Small → Build Habits → Increase Participation → Create Environmental Impact**

โฟกัสปัญหาสิ่งแวดล้อมที่ Ebetsu City เจอจริง: food waste, plastic waste, waste reduction, recycling

## 2. กลไกเกม (สำคัญมาก — ใช้ตอนออกแบบ Quest/Backend logic)

**Quest scoring** = Difficulty + Impact
- Difficulty: Easy=5, Medium=10, Hard=15
- Impact: Low=5, Medium=10, High=15
- ตัวอย่าง: Medium+High = 10+15 = 25 points

**หมวด Quest**: Food Waste Quest, Recycling/Waste Quest, Plastic Reduction Quest, Community Quest

**รูปแบบ Quest**:
- **Solo Quest** — ทำคนเดียว, ปรับความยากตาม level ผู้เล่นได้
- **Party/Community Quest** — ทำเป็นกลุ่ม (cleanup, tree planting) ผู้เล่นสร้าง event เองได้เมื่อถึง level ที่กำหนด องค์กรสิ่งแวดล้อมในพื้นที่อาจได้สิทธิ์สร้างโดยตรง

**Energy system**:
- max 5 energy, ทำ quest 1 ครั้ง = -1 energy, ฟื้นคืน +1 ทุก 5 นาที (cap ที่ 5)
- **Mini Quest "Check Your Food & Expiration Dates"** — บันทึกอาหารในตู้เย็น+วันหมดอายุ, อัปเดตได้วันละครั้ง, **ไม่เสีย energy แต่ได้ +1 energy แทน**

**XP / Level / Rank / Season / Points** (แยกกันชัดเจน อย่าสับสน):
- **XP** — สะสมถาวร ไม่ reset ใช้คำนวณ Level
- **Level** — ปลดล็อกฟีเจอร์ใหม่ (เช่น Level 10 ถึงจะสร้าง Party Event ได้)
- **Rank** (Bronze/Silver/Gold ฯลฯ) — อิงจาก XP แต่ **reset ทุก Season** (XP เองไม่ reset)
- **Points** — คนละตัวกับ XP ใช้แลก reward/upgrade ในหน้า Profile

**Achievement medals**: Food Saver, Recycling, Community, Plastic Reduction (เก็บสะสมได้)

**Inventory/Items**: ได้จาก quest/achievement/reward/event เช่นไอเทม Energy Drink (คูณคะแนน quest x2) — **ไอเทมนี้ถูกตัดออกจากดีไซน์จริงแล้ว ไม่ต้องใส่กลับมา**

## 3. Tech stack ที่ตัดสินใจแล้ว (สำคัญ — อย่าเปลี่ยนโดยไม่ถาม)

- **Frontend**: Flutter
- **Backend**: Node.js + Express (อยู่ใน `backend/`)
- **Database**: **MongoDB Atlas** — ⚠️ มีเอกสารออกแบบเก่าที่พูดถึง Firebase (project id `project-ecoquestapp-hiu`) **แต่ Firebase ถูกปัดตกไปแล้ว ไม่ได้ใช้งานจริง** ถ้าเห็นการอ้างอิง Firebase ที่ไหนให้ถือว่าเป็นของเก่าที่ไม่ได้ใช้
- **Auth**: email/password (signup+login) + guest login เท่านั้น — **ไม่มี** Google/Facebook/Line login
- **State management ฝั่ง Flutter**: Provider
- **โครงสร้างโฟลเดอร์ Flutter**: `lib/models`, `lib/pages` (auth, home, inventory, explore, party, profile), `lib/services`, `lib/widgets`, `lib/providers`, `lib/routes`, `lib/utils`, `main.dart` สั้นๆ (แค่ setup + routes)

## 4. โครงสร้าง MongoDB Collections (ออกแบบไว้แล้ว ไม่ embed)

- `users` — email, password, isGuest, displayName, level, xp, points, rank, seasonId, energy, lastEnergyUpdate
- `quests` — template ของ quest (มี static method `Quest.calculateScore(difficulty, impact)`)
- `questHistory` — แยก collection ต่างหาก (ไม่ embed ใน user)
- `fridgeItems` — สำหรับ Mini Quest เช็คอาหาร
- `items`/`inventory` — ไอเทมที่ผู้เล่นถือ
- `achievements` — medal ที่ปลดล็อกแล้ว (unique index กันซ้ำ)
- `seasons` — ควบคุมรอบ reset ของ Rank

Mongoose models ทั้งหมดอยู่ใน `backend/models/` **สร้างไว้ครบแล้ว** แค่ยังไม่มี route/controller สำหรับ quest/user/inventory (มีแค่ auth routes)

## 5. สถานะปัจจุบัน — อะไรทำงานจริง อะไรยัง mock

### ทำงานจริงแล้ว (ทดสอบผ่านบนเครื่อง Android จริงแล้ว)
- Register / Login / Guest login (ครบ flow, เชื่อม MongoDB Atlas จริง)
- Bottom nav (`MainShell` + `IndexedStack`) สลับ 5 แท็บ: Home, Inventory, Explore, Party, Profile
- หน้า Profile — UI ครบ, background เปลี่ยนรูปเองได้ (`lib/utils/assets/background.png`)
- หน้า Home — พื้นหลังคือหน้า Profile จริง + แผ่น "Explore" ลากขึ้น/ลงได้ (ลากขึ้นสุด→ไปแท็บ Explore, ลากลงสุด→ไปแท็บ Profile) มี animation + haptic + perf optimization (RepaintBoundary, ไม่ rebuild เนื้อหาหนักทุกเฟรม)
- หน้า Explore เต็มจอ — search bar, filter chips (All/Solo/Party/Event), quest list, pull-to-refresh, empty state
- หน้า Inventory — ลิสต์ไอเทม (Camera มีรูปจริงแล้ว, Fridge) + Achievement medals รวมกันในลิสต์เดียว, quantity badge สไตล์ liquid-glass (ดูรายละเอียดสเปคด้านล่าง)

### ยังเป็น placeholder / mock ทั้งหมด (มี `// TODO` กำกับในโค้ดแล้ว)
- **หน้า Party** — ยังเป็น placeholder เฉยๆ ยังไม่ได้ออกแบบ
- **ตัวเลขทั้งหมด** ใน Profile/Home (level, xp, points, rank, stats) เป็น mock data ในตัวโค้ด ยังไม่ได้ดึงจาก backend
- **Quest list** ใน Explore/Home เป็น mock (`mockQuestCards` ใน `lib/models/quest_card_model.dart`) ยังไม่มี `GET /api/quests` จริง
- **กด "Start"/"Join" บน quest card** ยังไม่เกิดอะไรขึ้นจริง (แค่ TODO comment)
- **Fridge item ใน Inventory** — กดแล้วมีแค่ SnackBar บอกว่า "กำลังจะมา" ยังไม่มีหน้ารายละเอียดจริง
- **Camera item** — กดแล้วมีแค่ SnackBar ยังไม่ได้เปิดกล้องจริง
- **Achievement/Inventory ทั้งหมด** — mock data ใน `achievement_model.dart` / `inventory_item_model.dart` ยังไม่มี backend endpoint

**Backend routes ที่ยังไม่มี (ต้องเขียนเพิ่ม)**: `GET /api/quests`, `POST /api/quests/:id/complete`, `GET /api/users/me`, `GET /api/inventory`, `GET /api/achievements`, `GET/POST /api/fridge-items`

## 6. รายละเอียดปลีกย่อยที่เคยเสียเวลาแก้ปัญหามาก่อน (กันเสียเวลาซ้ำ)

- **Asset path ต้องตรงกับ `pubspec.yaml` เป๊ะๆ ทุกตัวอักษร** ห้ามมี `/` นำหน้า และเปลี่ยน `pubspec.yaml` ต้อง `flutter clean` + full restart เท่านั้น hot reload/restart ไม่พอ
- รูปพื้นหลัง Profile: `lib/utils/assets/background.png`
- รูป Camera ใน Inventory: `lib/utils/assets/items/camera.png`
- **Quantity badge สไตล์ liquid-glass** (ใน `widgets/inventory_card.dart`): 39×16px, สี `#D9D9D9` โปร่งใส 80% (opacity 0.2), มุมโค้ง 20px, drop shadow (Y=4, blur=10, ดำ 50%) — shadow ต้องอยู่คนละ widget layer กับตัวที่ถูก `ClipRRect` ไม่งั้น shadow จะโดนตัดหายไปด้วย
- ทดสอบบนเครื่องจริงผ่าน USB ต้องใช้ `adb reverse tcp:5000 tcp:5000` ทุกครั้งที่เสียบสายใหม่ (ไม่ persist ข้าม session)
- ถ้าทดสอบผ่าน WiFi มหาวิทยาลัย/องค์กร อาจเจอ firewall บล็อกการเชื่อม MongoDB Atlas — ใช้ hotspot มือถือแทนได้
- `IndexedStack` ต้องครอบด้วย `SizedBox.expand` ไม่งั้นบางทีไม่ยอมขยายเต็มพื้นที่ (เจอปัญหาช่องว่างสีขาวมาก่อน)
- Gradle JDK ต้องเป็น JDK 17 (ไม่ใช่ JDK ใหม่กว่านี้) ไม่งั้น Gradle sync fail

## 7. งานถัดไปที่แนะนำ (เรียงตามลำดับที่ควรทำ)

1. เขียน backend routes สำหรับ Quest system (`GET /api/quests`, `POST /api/quests/:id/complete` — คำนวณคะแนน, หัก/เพิ่ม energy, อัปเดต XP/Level)
2. เขียน `GET /api/users/me` แล้วแทนที่ mock data ใน `profile_page.dart` และ `home_page.dart`
3. เขียน backend routes สำหรับ Inventory/Achievement แล้วต่อเข้ากับหน้า Inventory
4. ออกแบบหน้า Party (ยังไม่มีดีไซน์เลยตอนนี้)
5. ออกแบบหน้ารายละเอียด Fridge (ดู/แก้ไขอาหารที่บันทึกไว้ + วันหมดอายุ)
