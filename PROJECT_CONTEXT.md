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

> ⚙️ **สูตรทั้งหมดของ progression อยู่ที่ `backend/utils/progression.js` ไฟล์เดียว** (level curve, rank tier, energy regen)
> อยากปรับความยาก/ความเร็วของเกมให้แก้ที่นั่นที่เดียว **ห้าม hardcode ตัวเลขพวกนี้ซ้ำที่อื่น**
> - Level: XP ที่ต้องใช้เลื่อนจาก level L ไป L+1 = `100 × L` (L1→2 ใช้ 100, L2→3 ใช้ 200 …)
> - Rank tier ตาม XP ที่ได้ใน season ปัจจุบัน: Bronze 0 / Silver 500 / Gold 1500 / Platinum 3000 / Diamond 5000
> - **XP คือ source of truth** — level/rank คำนวณสดจาก XP เสมอ ส่วนฟิลด์ `user.level` / `user.rank` ใน DB เป็นแค่ cache
>   (ตอนเขียน endpoint ทำ quest สำเร็จ ต้องอัปเดต 2 ฟิลด์นี้ให้ตรงด้วย)

**Inventory/Items**: ได้จาก quest/achievement/reward/event เช่นไอเทม Energy Drink (คูณคะแนน quest x2) — **ไอเทมนี้ถูกตัดออกจากดีไซน์จริงแล้ว ไม่ต้องใส่กลับมา**

## 3. Tech stack ที่ตัดสินใจแล้ว (สำคัญ — อย่าเปลี่ยนโดยไม่ถาม)

- **Frontend**: Flutter
- **Backend**: Node.js + Express (อยู่ใน `backend/`)
- **Database**: **MongoDB Atlas** — ⚠️ มีเอกสารออกแบบเก่าที่พูดถึง Firebase (project id `project-ecoquestapp-hiu`) **แต่ Firebase ถูกปัดตกไปแล้ว ไม่ได้ใช้งานจริง** ถ้าเห็นการอ้างอิง Firebase ที่ไหนให้ถือว่าเป็นของเก่าที่ไม่ได้ใช้
- **Auth**: email/password (signup+login) + guest login เท่านั้น — **ไม่มี** Google/Facebook/Line login
- **ส่งอีเมล**: `nodemailer` ผ่าน Gmail SMTP (ใช้กับ OTP ลืมรหัสผ่าน) — ต้องมี `GMAIL_USER` + `GMAIL_APP_PASSWORD` ใน `backend/.env`
  โดย `GMAIL_APP_PASSWORD` ต้องเป็น App Password ที่สร้างจาก Google Account (เปิด 2FA ก่อน) **ไม่ใช่รหัสผ่าน Gmail ปกติ**
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
- **Logout** — หน้า Settings (เข้าจากปุ่มเฟืองมุมซ้ายบนหน้า Profile) มีข้อมูลบัญชี + ปุ่ม Logout
  ตอน logout ใช้ `pushNamedAndRemoveUntil` ล้าง stack ทั้งหมด (ไม่ใช่ `pushReplacementNamed` เหมือนที่อื่น) กันกด back กลับเข้าแอปหลัง logout
- **เปลี่ยนรหัสผ่าน** — 2 ขั้นตอน: กรอกรหัสเดิม → `POST /auth/verify-password` → ผ่านแล้วค่อยตั้งรหัสใหม่ → `POST /auth/change-password`
  (ฝั่ง backend verify รหัสเดิมซ้ำอีกรอบตอนเปลี่ยนจริง ไม่ได้เชื่อผลจากขั้นตอนแรกอย่างเดียว)
- **ลืมรหัสผ่าน (OTP ทางอีเมล)** — 3 ขั้นตอนในหน้าเดียว: กรอกอีเมล → OTP 6 หลัก → ตั้งรหัสใหม่
  OTP เก็บใน DB เป็น bcrypt hash (`resetOtpHash`) หมดอายุ 10 นาที ใช้ได้ครั้งเดียว, ยืนยันผ่านแล้วได้ JWT `purpose: 'password_reset'` อายุ 10 นาที ไว้ใช้ตั้งรหัสใหม่
  `POST /auth/forgot-password` **ตอบข้อความเดียวกันเสมอ** ไม่ว่าอีเมลจะมีในระบบหรือไม่ (กันคนไล่เดารายชื่ออีเมลที่สมัครไว้) — อย่าเผลอแก้ให้มันบอกว่า "ไม่พบอีเมลนี้"
- **หน้า Party** — โชว์รายชื่อปาร์ตี้ (Party Leader บนสุดกดดูโปรไฟล์ได้ + สมาชิก) + ปุ่ม Leave Party
  ถ้ายังไม่มีปาร์ตี้จะเป็น empty state "คุณยังไม่มีปาร์ตี้" + ปุ่มพาไปแท็บ Explore (ข้อมูลยัง mock อยู่ใน `lib/models/party_model.dart`)
- **หน้า Profile ใช้ข้อมูลจริงแล้ว** — level / xp / points / rank / stats ดึงจาก `GET /api/auth/me`
  (หน้า Home ได้ตามไปด้วยอัตโนมัติ เพราะใช้ `ProfilePage` ตัวจริงเป็นพื้นหลัง) ดึงลงเพื่อ refresh ได้ในแท็บ Profile
- Bottom nav (`MainShell` + `IndexedStack`) สลับ 5 แท็บ: Home, Inventory, Explore, Party, Profile
- หน้า Profile — UI ครบ, background เปลี่ยนรูปเองได้ (`lib/utils/assets/background.png`)
- หน้า Home — พื้นหลังคือหน้า Profile จริง + แผ่น "Explore" ลากขึ้น/ลงได้ (ลากขึ้นสุด→ไปแท็บ Explore, ลากลงสุด→ไปแท็บ Profile) มี animation + haptic + perf optimization (RepaintBoundary, ไม่ rebuild เนื้อหาหนักทุกเฟรม)
- หน้า Explore เต็มจอ — search bar, filter chips (All/Solo/Party/Event), quest list, pull-to-refresh, empty state
- หน้า Inventory — ลิสต์ไอเทม (Camera มีรูปจริงแล้ว, Fridge) + Achievement medals รวมกันในลิสต์เดียว, quantity badge สไตล์ liquid-glass (ดูรายละเอียดสเปคด้านล่าง)

### ยังเป็น placeholder / mock ทั้งหมด (มี `// TODO` กำกับในโค้ดแล้ว)
- **สมาชิกปาร์ตี้** ในหน้า Party เป็น mock (`mockParty` ใน `lib/models/party_model.dart`) ยังไม่มี Party API จริง
  (ตั้ง `mockParty = null` เพื่อดู empty state ได้)
- **การ์ด "Upgrade your Ability"** ในหน้า Profile ยัง mock อยู่ — ยังไม่มี model/endpoint ของ upgrade ฝั่ง backend เลย
- **Quest list** ใน Explore/Home เป็น mock (`mockQuestCards` ใน `lib/models/quest_card_model.dart`) ยังไม่มี `GET /api/quests` จริง
- **กด "Start"/"Join" บน quest card** ยังไม่เกิดอะไรขึ้นจริง (แค่ TODO comment)
- **Fridge item ใน Inventory** — กดแล้วมีแค่ SnackBar บอกว่า "กำลังจะมา" ยังไม่มีหน้ารายละเอียดจริง
- **Camera item** — กดแล้วมีแค่ SnackBar ยังไม่ได้เปิดกล้องจริง
- **Achievement/Inventory ทั้งหมด** — mock data ใน `achievement_model.dart` / `inventory_item_model.dart` ยังไม่มี backend endpoint

**Backend routes ที่มีแล้ว** (ทั้งหมดอยู่ใน `backend/routes/auth.js` ไฟล์เดียว mount ที่ `/api/auth`):
`POST /register`, `POST /login`, `POST /guest`, `GET /me`, `POST /verify-password`, `POST /change-password`,
`POST /forgot-password`, `POST /verify-reset-otp`, `POST /reset-password`

`GET /api/auth/me` คืน 3 ก้อน: `user` (+ level/xp/points/rank/energy), `progress` (ความคืบหน้า level/rank),
`stats` (questCompleted / questTotal / co2SavedKg / partiesJoined — คำนวณจริงจาก `QuestHistory` + `Quest`)

**Backend routes ที่ยังไม่มี (ต้องเขียนเพิ่ม)**: `GET /api/quests`, `POST /api/quests/:id/complete`, `GET /api/inventory`, `GET /api/achievements`, `GET/POST /api/fridge-items`

## 6. รายละเอียดปลีกย่อยที่เคยเสียเวลาแก้ปัญหามาก่อน (กันเสียเวลาซ้ำ)

- **Asset path ต้องตรงกับ `pubspec.yaml` เป๊ะๆ ทุกตัวอักษร** ห้ามมี `/` นำหน้า และเปลี่ยน `pubspec.yaml` ต้อง `flutter clean` + full restart เท่านั้น hot reload/restart ไม่พอ
- รูปพื้นหลัง Profile: `lib/utils/assets/background.png`
- รูป Camera ใน Inventory: `lib/utils/assets/items/camera.png`
- **Quantity badge สไตล์ liquid-glass** (ใน `widgets/inventory_card.dart`): 39×16px, สี `#D9D9D9` โปร่งใส 80% (opacity 0.2), มุมโค้ง 20px, drop shadow (Y=4, blur=10, ดำ 50%) — shadow ต้องอยู่คนละ widget layer กับตัวที่ถูก `ClipRRect` ไม่งั้น shadow จะโดนตัดหายไปด้วย
- ทดสอบบนเครื่องจริงผ่าน USB ต้องใช้ `adb reverse tcp:5000 tcp:5000` ทุกครั้งที่เสียบสายใหม่ (ไม่ persist ข้าม session)
- ⚠️ **`AppConstants.baseUrl` ต้องสลับค่าตามอุปกรณ์ที่ทดสอบ** (เคยเสียเวลากับเรื่องนี้มาแล้ว — อาการคือ `SocketException: Connection timed out`)
  - **เครื่องจริง + `adb reverse`** → `http://127.0.0.1:5000/api` ← ค่าปัจจุบัน
  - **Android Emulator** → `http://10.0.2.2:5000/api` (`10.0.2.2` เป็น IP พิเศษของ emulator เท่านั้น บนเครื่องจริงไม่มี IP นี้อยู่จริง เลย timeout)
  - เปลี่ยนค่านี้แล้วต้อง **hot restart** ไม่ใช่แค่ hot reload
- ถ้าทดสอบผ่าน WiFi มหาวิทยาลัย/องค์กร อาจเจอ firewall บล็อกการเชื่อม MongoDB Atlas — ใช้ hotspot มือถือแทนได้
- `IndexedStack` ต้องครอบด้วย `SizedBox.expand` ไม่งั้นบางทีไม่ยอมขยายเต็มพื้นที่ (เจอปัญหาช่องว่างสีขาวมาก่อน)
- Gradle JDK ต้องเป็น JDK 17 (ไม่ใช่ JDK ใหม่กว่านี้) ไม่งั้น Gradle sync fail

## 7. งานถัดไปที่แนะนำ (เรียงตามลำดับที่ควรทำ)

1. **Quest system** (งานชิ้นใหญ่สุดและเป็นหัวใจของเกม) — `GET /api/quests` + `POST /api/quests/:id/complete`
   ตอน complete ต้อง: เช็ค/หัก energy, บันทึก `QuestHistory`, บวก XP + points ให้ user, อัปเดต cache `user.level`/`user.rank`
   ด้วย `backend/utils/progression.js` แล้วต่อเข้ากับ Explore/Home (แทน `mockQuestCards`)
   — ยังไม่มี quest ตัวจริงใน DB เลย ต้อง seed ด้วย (อย่าลืมใส่ `co2SavedKg` ไม่งั้นสถิติ CO2 จะเป็น 0 ตลอด)
2. เขียน backend routes สำหรับ Inventory/Achievement แล้วต่อเข้ากับหน้า Inventory
   (Achievement น่าจะรอ Quest system ก่อน เพราะ medal ปลดล็อกจากการทำ quest)
3. ออกแบบหน้ารายละเอียด Fridge (ดู/แก้ไขอาหารที่บันทึกไว้ + วันหมดอายุ) + `GET/POST /api/fridge-items`
   — Mini Quest นี้ไม่เสีย energy แต่ได้ +1 energy และทำได้วันละครั้ง
4. Party API จริง (สร้าง/เข้าร่วม/ออกจากปาร์ตี้) แทน `mockParty` — ยังไม่มี Party/Event model ฝั่ง backend เลย
   (ตอนนี้ `Quest.type` มีแค่ `'solo'` / `'party'` และมี `minLevelToHost` รออยู่)
5. Season — ยังไม่มี season ตัวจริงใน DB สักอัน ทำให้ Rank ยังนับ XP ไม่ได้ (`seasonXp` = 0 ตลอด)
   ต้อง seed season ที่ `isActive: true` สักอันก่อน Rank ถึงจะเริ่มขยับ
