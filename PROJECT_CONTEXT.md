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

**~~Energy system~~ — ❌ ตัดออกจากดีไซน์แล้ว ไม่ต้องเอากลับมา**
- เดิมออกแบบไว้ว่า max 5 energy, ทำ quest 1 ครั้ง = -1 energy, ฟื้น +1 ทุก 5 นาที — **ยกเลิกแล้ว ทำ quest ได้ไม่จำกัด ไม่เสียพลังงาน**
- ลบออกจากโค้ดหมดแล้ว: ฟิลด์ `energy`/`lastEnergyUpdate` ใน `User`, ฟังก์ชัน `currentEnergy` ใน `progression.js`,
  ฟิลด์ `energy` ใน `UserModel` ฝั่ง Flutter, แถบ energy ในการ์ด quest
- ถ้าเจอเอกสารเก่าที่พูดถึง energy ให้ถือว่าเป็นของเก่าที่ไม่ได้ใช้ (เหมือนกรณี Firebase)
- **Mini Quest "Check Your Food & Expiration Dates"** — บันทึกอาหารในตู้เย็น+วันหมดอายุ, อัปเดตได้วันละครั้ง
  (เดิมรางวัลคือ +1 energy — ตอนนี้ต้องตัดสินใจใหม่ว่าจะให้รางวัลเป็นอะไรแทน ยังไม่ได้ข้อสรุป)

**XP / Level / Rank / Season / Points** (แยกกันชัดเจน อย่าสับสน):
- **XP** — สะสมถาวร ไม่ reset ใช้คำนวณ Level
- **Level** — ปลดล็อกฟีเจอร์ใหม่ (เช่น Level 10 ถึงจะสร้าง Party Event ได้)
- **Rank** (Bronze/Silver/Gold ฯลฯ) — อิงจาก XP แต่ **reset ทุก Season** (XP เองไม่ reset)
- **Points** — คนละตัวกับ XP ใช้แลก reward/upgrade ในหน้า Profile

**Achievement medals**: Food Saver, Recycling, Community, Plastic Reduction (เก็บสะสมได้)

> ⚙️ **สูตรทั้งหมดของ progression อยู่ที่ `backend/utils/progression.js` ไฟล์เดียว** (level curve, rank tier)
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
- **โครงสร้างโฟลเดอร์ Flutter**: `lib/models`, `lib/pages` (auth, home, inventory, explore, party, profile, settings, notification), `lib/services`, `lib/widgets`, `lib/providers`, `lib/routes`, `lib/utils`, `main.dart` สั้นๆ (แค่ setup + routes)
- 🌐 **ภาษาในแอพ: อังกฤษล้วน** (ตัดสินใจแล้ว แปลงทั้งโปรเจคไปเรียบร้อยแล้ว)
  - **ทุกข้อความที่ผู้ใช้เห็นต้องเป็นภาษาอังกฤษ** — รวมถึง `message` ที่ backend ส่งกลับมาด้วย
    เพราะข้อความ error จาก API ถูกเอาไปโชว์ใน SnackBar ของแอพตรงๆ (ถ้าเขียนไทยฝั่ง backend ผู้ใช้จะเห็นไทยทันที)
  - **คอมเมนต์ในโค้ดยังเป็นภาษาไทย** ต่อไปเหมือนเดิม — เป็นเอกสารสำหรับเจ้าของโปรเจค ไม่ใช่สิ่งที่ผู้ใช้เห็น
  - เขียนโค้ดใหม่ต่อจากนี้ให้ยึดกฎนี้: string ที่โชว์บนจอ = อังกฤษ, คอมเมนต์ = ไทย

## 4. โครงสร้าง MongoDB Collections (ออกแบบไว้แล้ว ไม่ embed)

- `users` — email, password, isGuest, displayName, level, xp, points, rank, seasonId
  \+ `resetOtpHash`, `resetOtpExpires` (เพิ่มทีหลังสำหรับ flow ลืมรหัสผ่าน — เก็บ **hash** ของ OTP ไม่ใช่ตัวเลขจริง)
  \- เอา `energy` / `lastEnergyUpdate` ออกแล้ว (ระบบ Energy ถูกตัดจากดีไซน์)
- `quests` — template ของ quest (มี static method `Quest.calculateScore(difficulty, impact)`)
  \+ `co2SavedKg` (เพิ่มทีหลัง — ใช้รวมเป็นสถิติ "CO2 Saved" ในหน้า Profile, ตอน seed quest ต้องใส่ค่านี้ด้วย)
- `questHistory` — แยก collection ต่างหาก (ไม่ embed ใน user)
- `fridgeItems` — สำหรับ Mini Quest เช็คอาหาร (`itemName`, `expirationDate`, `quantity`, `addedAt`)
  ⚠️ ยังไม่มีฟิลด์เก็บ path รูปถ่าย — ตอนทำฟีเจอร์กล้องต้องเพิ่มเอง (ฝั่ง Flutter ใช้ชื่อ `photoPath`)
- `items`/`inventory` — ไอเทมที่ผู้เล่นถือ
- `achievements` — medal ที่ปลดล็อกแล้ว (unique index กันซ้ำ)
- `seasons` — ควบคุมรอบ reset ของ Rank

Mongoose models ทั้งหมดอยู่ใน `backend/models/` **สร้างไว้ครบแล้ว** แค่ยังไม่มี route/controller สำหรับ quest/user/inventory (มีแค่ auth routes)

## 5. สถานะปัจจุบัน — อะไรทำงานจริง อะไรยัง mock

### ทำงานจริงแล้ว (ทดสอบผ่านบนเครื่อง Android จริงแล้ว)
- Register / Login / Guest login (ครบ flow, เชื่อม MongoDB Atlas จริง)
- **Logout** — หน้า Settings (เข้าจากปุ่มเฟืองมุมซ้ายบนหน้า Profile) มีข้อมูลบัญชี + ปุ่ม Logout
  ตอน logout ใช้ `pushNamedAndRemoveUntil` ล้าง stack ทั้งหมด (ไม่ใช่ `pushReplacementNamed` เหมือนที่อื่น) กันกด back กลับเข้าแอปหลัง logout
- **อัปเกรด Guest -> บัญชีปกติ** — เมนู "Create an account" ในหน้า Settings (โชว์เฉพาะตอนเป็น Guest)
  กรอกชื่อ + email + password แล้วเรียก `POST /auth/upgrade-guest`
  - ⚠️ ที่ต้องมีฟีเจอร์นี้: **บัญชี Guest กู้คืนไม่ได้เลยถ้า logout** เพราะไม่มี email/password ให้ล็อกอินกลับ
    (เมนูนี้เลยทำให้เด่นกว่าเมนูอื่น + เขียนกำกับไว้ว่าข้อมูลจะหายถ้า logout)
  - **ใช้ `_id` เดิม ไม่ได้สร้าง user ใหม่** → points / XP / ประวัติ quest / ของในตู้เย็น ติดมาครบ
    และ **token เดิมยังใช้ได้ต่อ** (ข้างในเก็บ userId ซึ่งไม่เปลี่ยน) ไม่ต้อง login ใหม่
  - กันไว้แล้ว: อีเมลซ้ำ -> 409, อัปเกรดซ้ำตอนไม่ใช่ guest แล้ว -> 400, password สั้นกว่า 6 -> 400
- **เปลี่ยนรหัสผ่าน** — 2 ขั้นตอน: กรอกรหัสเดิม → `POST /auth/verify-password` → ผ่านแล้วค่อยตั้งรหัสใหม่ → `POST /auth/change-password`
  (ฝั่ง backend verify รหัสเดิมซ้ำอีกรอบตอนเปลี่ยนจริง ไม่ได้เชื่อผลจากขั้นตอนแรกอย่างเดียว)
- **ลืมรหัสผ่าน (OTP ทางอีเมล)** — 3 ขั้นตอนในหน้าเดียว: กรอกอีเมล → OTP 6 หลัก → ตั้งรหัสใหม่
  OTP เก็บใน DB เป็น bcrypt hash (`resetOtpHash`) หมดอายุ 10 นาที ใช้ได้ครั้งเดียว, ยืนยันผ่านแล้วได้ JWT `purpose: 'password_reset'` อายุ 10 นาที ไว้ใช้ตั้งรหัสใหม่
  `POST /auth/forgot-password` **ตอบข้อความเดียวกันเสมอ** ไม่ว่าอีเมลจะมีในระบบหรือไม่ (กันคนไล่เดารายชื่ออีเมลที่สมัครไว้) — อย่าเผลอแก้ให้มันบอกว่า "ไม่พบอีเมลนี้"
- **หน้า Party** — โชว์รายชื่อปาร์ตี้ (Party Leader บนสุดกดดูโปรไฟล์ได้ + สมาชิก) + ปุ่ม Leave Party
  ถ้ายังไม่มีปาร์ตี้จะเป็น empty state ("You're not in a party yet") + ปุ่มพาไปแท็บ Explore (ข้อมูลยัง mock อยู่ใน `lib/models/party_model.dart`)
- **Quest system ใช้งานได้จริงแล้ว (end-to-end)** — `GET /api/quests` + `POST /api/quests/:id/complete`
  กด Start บนการ์ด → บันทึก `QuestHistory` → บวก points/XP → อัปเดต cache `user.level` → รีเฟรชโปรไฟล์ให้เลขในหน้า Profile ขยับตาม
  - **quest รายวัน (`isDaily`)** ทำซ้ำในวันเดียวกันไม่ได้ — backend ตอบ 409 และการ์ดจะขึ้นปุ่ม "Done" กดไม่ได้
  - ลิสต์ quest แชร์กันผ่าน `QuestProvider` ตัวเดียว ระหว่างหน้า Explore กับแผ่น Explore ในหน้า Home
    (โหลดครั้งเดียวใน `MainShell.initState` ไม่ให้ 2 หน้ายิง API ซ้ำ เพราะอยู่ใน `IndexedStack` พร้อมกันตลอด)
  - **มี quest ใช้งานได้ 15 อัน** ครอบ 5 หมวด (food_waste / recycling / plastic / **energy** / community)
    seed มาจาก `Quest_list.md` ที่เจ้าของโปรเจคเขียนไว้ — แก้/เพิ่มได้ที่ `backend/scripts/seedQuests.js` แล้วรัน `npm run seed:quests`
    (สคริปต์เป็น upsert อิง `title` — รันซ้ำได้ไม่สร้างของซ้ำ แต่**ลบ quest ออกจากไฟล์แล้วจะไม่ลบออกจาก DB** ต้องลบเองใน DB หรือตั้ง `isActive: false`)
  - 🎲 **ระบบกลุ่มสุ่ม (`Quest.randomPool`)** — quest ที่อยู่กลุ่มเดียวกันจะโผล่แค่ **วันละ 1 อัน**
    ตอนนี้มีกลุ่มเดียวคือ `food_saver` (Food Saver 1 Day / 3 Days / 7 Days) — **ไม่ได้ใช้ระบบนับ streak**
    - เลือกด้วย hash ของ `(userId + วันที่ + ชื่อกลุ่ม)` → **สุ่มแต่คงที่**: คนเดิมได้อันเดิมทั้งวัน
      ดึงรีเฟรชกี่ครั้งก็ไม่เปลี่ยน (กันรีเฟรชรัวๆ จนได้อันคะแนนสูงสุด) ข้ามเที่ยงคืนถึงสุ่มใหม่
    - ทดสอบแล้ว: คนละคนได้คนละอัน, เรียกซ้ำได้อันเดิม, กระจายตัว ≈33% เท่ากันทั้ง 3 อัน
    - เพิ่มกลุ่มใหม่ได้แค่ใส่ `randomPool: 'ชื่อกลุ่ม'` ให้ quest หลายอัน ไม่ต้องแก้โค้ด route
  - ✅ `Community Cleanup` เปิดใช้งานแล้ว (เป็น party quest ตัวจริง) — ดูหัวข้อ "ระบบ Party" ด้านล่าง
    ถ้าเปิดตอนนี้จะกลายเป็นกดปุ่มรับ 30 แต้มฟรี
  - ⚠️ **ค่า `co2SavedKg` ทุกอันเป็นค่าประมาณ ยังไม่ได้อ้างอิงงานวิจัยจริง** ถ้าจะเอาไปนำเสนอควรหาตัวเลขอ้างอิงมาแทน
  - **Season 1 seed แล้ว** (`npm run seed:season`, ยาว 90 วัน) — Rank เริ่มขยับได้จริงแล้ว
    ทดสอบแล้ว: ทำ quest 1 อัน -> `seasonXp` 0→10, `rankXpIntoTier` 0→10
    ⚠️ **ถ้าไม่มี season ที่ `isActive: true` แถบ Rank จะค้างที่ Bronze 0/500 ตลอด** ทั้งที่โค้ดถูก — season หมดอายุเมื่อไหร่ต้อง seed อันใหม่
- **Mini Quest "เช็คของในตู้เย็น" ทำงานจริงแล้ว (ไม่ใช่กดรับคะแนนเปล่าๆ)**
  - `Quest.actionKey` = key บอกว่า quest นี้ต้องทำ action จริงในแอพก่อน (`null` = กดยืนยันเองได้เลย)
    quest เช็คตู้เย็นใช้ `actionKey: 'fridge_check'`
  - กด Start บนการ์ด → **ไม่ได้กดจบ quest ทันที** แต่พาไปหน้า Fridge (`/fridge`)
  - หน้า Fridge เพิ่มของได้จริง (**รูปถ่าย** + ชื่อ + วันหมดอายุ + จำนวน) กรอกได้หลายชิ้นแล้วกด Save ทีเดียว
    (backend รับเป็น array) พอ Save สำเร็จจะกดจบ quest ให้อัตโนมัติแล้วเด้งรางวัลขึ้นมา
  - **ปุ่ม Save อยู่มุมขวาบน** ของหน้า (โผล่เฉพาะตอนมีของที่ยังไม่ได้บันทึก พร้อมโชว์จำนวน)
  - ตัวช่วยให้กรอกไว: โฟกัสช่องชื่อให้อัตโนมัติ, ปุ่มลัดวันหมดอายุ (3 days / 1 week / 1 month),
    ปุ่ม "Add another" ที่ไม่ปิด sheet เพื่อกรอกชิ้นถัดไปต่อได้เลย, การ์ดใหม่ fade+slide เข้ามา
  - **backend เช็คซ้ำอีกชั้น**: `POST /quests/:id/complete` ของ quest ที่ `actionKey === 'fridge_check'`
    จะตอบ 400 ถ้ายังไม่มี `FridgeItem` ที่ `addedAt` เป็นวันนี้ — ยิง API ตรงๆ ก็โกงไม่ได้
  - กดค้างที่การ์ดของในตู้เย็น = ลบของชิ้นนั้น (มี dialog ยืนยัน)
- **ไอเทม Camera ใช้งานได้จริง** — กดไอเทม Camera ในหน้า Inventory เข้าหน้า `/camera`
  - ถ่ายรูป (หรือเลือกจากคลังรูป) แล้วได้การ์ด **"EcoQuest Moment"** ที่ตกแต่งเฉพาะของแอพ
    ดีไซน์: การ์ดขาวทรงโพลารอยด์ ขอบเขียว + รูปจัตุรัส, ป้าย EcoQuest มุมซ้ายบน,
    ชิป **Lv. / Rank ของผู้เล่นจริง** ทับมุมซ้ายล่างของรูป, ใต้รูปเป็นชื่อผู้เล่น + `Ebetsu City · วันที่` + ไอคอนใบไม้
  - **รูปที่เซฟคือรูปใหม่ที่ตกแต่งแล้ว** ไม่ใช่รูปดิบ — เรนเดอร์การ์ดทั้งใบเป็น PNG ด้วย `RepaintBoundary.toImage()`
    (ต้องครอบ `RepaintBoundary` เฉพาะการ์ด ไม่งั้นปุ่ม/พื้นหลังหน้าจอจะติดไปในรูปด้วย)
  - มีแกลเลอรีในแอพ (grid) กดดูรูปเต็ม/ลบได้ — เก็บ path ไว้ใน `SharedPreferences` (`camera_photos`)
  - **ปุ่ม "Save to device"** เซฟรูปลงแกลเลอรีของเครื่องจริง (อัลบั้ม `EcoQuest`) ด้วย package `gal`
    มีทั้งในหน้าพรีวิวก่อนเซฟ และในหน้าดูรูปที่เซฟไว้แล้ว — **คนละอย่างกับปุ่ม "Save Moment"**
    ที่เก็บไว้ในคอลเลกชันในแอพเท่านั้น
    ต้องมี `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>`
    ใน `AndroidManifest.xml` (ใส่ไว้แล้ว) — Android 10+ ไม่ต้องขอสิทธิ์เพราะเขียนผ่าน MediaStore
    และเวลาเช็คสิทธิ์ต้องใช้ `Gal.hasAccess(toAlbum: true)` ให้ตรงกับที่เซฟลงอัลบั้มชื่อเอง
  - ✅ **รูปเก็บถาวรแล้ว ไม่หายตอนเคลียร์ cache** — ผ่าน `lib/services/app_photo_storage.dart`
    (`AppPhotoStorage`) ที่ copy ไฟล์ไป `getApplicationDocumentsDirectory()` (ต้องลง `path_provider`
    แล้ว, เพิ่มแล้วใน `pubspec.yaml`) แทนที่จะปล่อยไว้ใน cache ของ `image_picker`/`Directory.systemTemp`
    เก็บลง DB/SharedPreferences เป็น **ชื่อไฟล์** เท่านั้น (ไม่ใช่ absolute path เพราะ documents dir
    เปลี่ยนได้ข้ามเครื่อง/รุ่น) แล้วค่อย `AppPhotoStorage.resolve()` เป็น absolute path ตอนจะวาดรูปจริง
    ต้องเรียก `AppPhotoStorage.init()` ก่อน `runApp()` เสมอ (ทำไว้ใน `lib/main.dart` แล้ว)
    รองรับค่าเก่าที่เคยเป็น absolute path เต็มด้วย (`resolve()` เช็คว่ามี `/` ในค่าไหม)
    — `PhotoStorageService.loadPhotos()` ยังเป็นจุด migrate รูปเก่าที่ยังไม่โดนเคลียร์ให้อัตโนมัติด้วย
- **รูปโปรไฟล์ (avatar) ใส่ได้จริงแล้ว** — แตะที่ avatar ในหน้า Profile (`UserHeader` ใน
  `lib/widgets/profile_sections.dart`) เปิด bottom sheet ให้ถ่ายรูป / เลือกจากคลังรูป / ลบรูป
  (ลบโชว์เฉพาะตอนมีรูปอยู่แล้ว) — copy ไฟล์ผ่าน `AppPhotoStorage` เหมือนรูปของในตู้เย็น
  - `User.avatarPath` (backend) + `POST /api/auth/avatar` (body `{avatarPath}`, ส่ง `null` เพื่อลบ)
    อัปเดตแล้ว `AuthProvider.updateAvatar()` จะเรียก `refreshProfile()` ต่อให้ทุกหน้าที่ใช้ `user.avatarPath` เห็นค่าใหม่ทันที
  - ⚠️ **เก็บแค่ path ในเครื่องเหมือน `FridgeItem.photoPath`** ไม่ได้อัปโหลดไฟล์จริงขึ้น server
    (โปรเจคยังไม่มี multer/cloud storage) เลยเห็นรูปได้แค่บนเครื่องที่ตั้งค่าไว้ — ถ้า login เครื่องอื่นจะไม่เห็นรูป
    (แต่รูปจะไม่หายจากเครื่องเดิมแล้วต่อให้เคลียร์ cache เพราะเก็บถาวรผ่าน `AppPhotoStorage`)
  - ยังไม่โชว์ avatar ของ**คนอื่น**ที่ไหนในแอพ (เช่นรายชื่อสมาชิกปาร์ตี้ยังเป็นไอคอนคนทั่วไปเหมือนเดิม)
    เพราะเป็น path ในเครื่องของเจ้าของรูป เครื่องอื่นเปิดไม่ได้อยู่ดี ต้องทำ upload ขึ้น server ก่อนถึงจะทำได้จริง
- **Achievement system ใช้งานได้จริง** — `GET /api/achievements` + ปลดล็อกอัตโนมัติตอนทำ quest สำเร็จ
  - นิยามเหรียญ + เงื่อนไขปลดล็อกทั้งหมดอยู่ที่ **`backend/utils/achievements.js` ไฟล์เดียว**
    (แนวเดียวกับ `progression.js`) — อยากปรับให้ปลดล็อกง่ายขึ้นตอนเดโมก็ลดเลข `required` ได้เลย
  - เหรียญตอนนี้: Food Saver / Recycling / Plastic Reduction / **Energy Saver** / Community
    เงื่อนไข = ทำ quest ในหมวดนั้นครบ **10 ครั้ง** (ยกเว้น Community = 1 ครั้ง เพราะเป็นงานลงพื้นที่จริง)
  - ⚠️ `medalType` **ห้ามเปลี่ยนหลังมีคนปลดล็อกแล้ว** เพราะเป็นคีย์ที่บันทึกลง DB (มี unique index กันซ้ำ)
  - API ส่งกลับ**ทั้งเหรียญที่ปลดล็อกแล้วและยังไม่ปลดล็อก** พร้อม `progress/required`
    หน้า Inventory เลยโชว์เหรียญที่ยังล็อกเป็นสีเทาพร้อมความคืบหน้า (เช่น `3/10`) ให้เห็นว่าเหลืออีกเท่าไหร่
  - ตอนทำ quest สำเร็จ response จะมี `newAchievements` ติดมาด้วย -> แอพเด้ง dialog แสดงความยินดี
  - โค้ด "หลังทำ quest สำเร็จ" รวมไว้ที่ `lib/utils/quest_completion.dart` ตัวเดียว
    ใช้ร่วมกัน 3 ที่ (Explore / แผ่น Explore ใน Home / Fridge) — แก้ที่เดียวพอ
  - ✅ `Community` ปลดล็อกได้แล้ว เพราะมี party quest หมวด community เปิดใช้งานอยู่
- **Quest History ในหน้า Profile** — การ์ดล่างสุด (ต่อจาก Upgrade your Ability) โชว์ quest ที่ทำสำเร็จ
  แต่ละแถว: ไอคอนตามหมวด + ชื่อ quest + วันที่สำเร็จ + คะแนนที่ได้ (`+10 P`) ข้อมูลจริงจาก `GET /api/quests/history`
  ⚠️ **ยังไม่มี "รูป quest" จริงในระบบ** (`Quest` model ไม่มีฟิลด์รูป, ไม่มีไฟล์ภาพใน assets)
  ตอนนี้ใช้ไอคอนตามหมวดแทน (food_waste / recycling / plastic / community) — ถ้าเพิ่มฟิลด์รูปทีหลัง
  แก้แค่ตรง `_QuestHistoryRow` ในหน้า Profile จุดเดียว (การ์ด quest ในหน้า Explore ก็ยังเป็นกล่องเทา placeholder เหมือนกัน)
- **หน้า Profile ใช้ข้อมูลจริงแล้ว** — level / xp / points / rank / stats ดึงจาก `GET /api/auth/me`
  (หน้า Home ได้ตามไปด้วยอัตโนมัติ เพราะใช้ `ProfilePage` ตัวจริงเป็นพื้นหลัง) ดึงลงเพื่อ refresh ได้ในแท็บ Profile
- Bottom nav (`MainShell` + `IndexedStack`) สลับ 5 แท็บ: Home, Inventory, Explore, Party, Profile
- หน้า Profile — UI ครบ, background เปลี่ยนรูปเองได้ (`lib/utils/assets/background.png`)
- หน้า Home — พื้นหลังคือหน้า Profile จริง + แผ่น "Explore" ลากขึ้น/ลงได้ (ลากขึ้นสุด→ไปแท็บ Explore, ลากลงสุด→ไปแท็บ Profile) มี animation + haptic + perf optimization (RepaintBoundary, ไม่ rebuild เนื้อหาหนักทุกเฟรม)
- หน้า Explore เต็มจอ — search bar, filter chips (All/Solo/Party/Event), quest list, pull-to-refresh, empty state
- หน้า Inventory — ลิสต์ไอเทม (Camera, Fridge — มีรูปจริงทั้งคู่แล้ว) + Achievement medals รวมกันในลิสต์เดียว, quantity badge สไตล์ liquid-glass (ดูรายละเอียดสเปคด้านล่าง)
- **หน้า Notification** — เข้าจากปุ่มกระดิ่งมุมขวาบนหน้า Profile (route `/notifications`) ไม่มี bottom nav
  หน้าตาอิงหน้า Inventory: พื้นหลัง `Colors.grey.shade50`, หัวข้อเขียว 22 bold, การ์ดขนาดเท่า `InventoryCard`
  รูปอยู่ที่ `lib/utils/assets/notifications/` (`trophy.png`, `fridge_expired.png`)
- **หน้า Fridge (ของในตู้เย็น)** — กดไอเทม Fridge ในหน้า Inventory เข้าไปได้ (route `/fridge`)
  ใช้ `InventoryCard` ตัวเดียวกับหน้า Inventory (ชื่อ + badge จำนวน) ส่วนบรรทัดรายละเอียดโชว์วันหมดอายุ + **นับถอยหลังสดทุกวินาที**
  - เหลือ **เกิน 24 ชม.** → `วัน:ชม:นาที` (เช่น `5:01:07`)
  - เหลือ **ไม่ถึง 24 ชม.** → `ชม:นาที:วินาที` (เช่น `08:14:33`)
  - **หมดอายุแล้ว** → ข้อความเป็น **สีแดง**
  - ใช้ `Timer.periodic` 1 วินาทีตัวเดียวทั้งหน้า (ไม่ใช่ timer แยกต่อการ์ด) และ `cancel()` ใน `dispose()` แล้ว

- **ระบบ Party (ห้อง/lobby ที่ผู้เล่นสร้างเอง) — ใช้งานได้จริงแล้ว ไม่ใช่ mock**
  แนวคิดใหม่ (เดิม party quest = ปาร์ตี้ไปในตัว, ตอนนี้แยกออกจากกันแล้ว): **party quest เป็นแค่ "แม่แบบ"**
  ผู้เล่นต้อง**กดสร้างห้อง (Party)** จาก quest นั้นก่อน ตั้งชื่อห้อง/วันเวลา/สถานที่/จำนวนคนรับเอง
  แล้วคนอื่นค่อยมากดเข้าร่วมห้องที่มีอยู่ — เหมือนห้องในเกมที่มีลิสต์ให้เลือก ไม่ใช่กด Join ที่ตัว quest ตรงๆ
  - `backend/models/Party.js` (**collection ใหม่**) — `{ questId, leaderId, name, eventDate, location, capacity, status: 'open'|'completed', completedAt }`
    1 quest template สร้างได้หลายห้อง คนละเวลา/สถานที่กัน
  - `backend/models/PartyMember.js` — ผูกกับ `partyId` (เดิมผูกกับ `questId` ตรงๆ) + unique index `(partyId, userId)`
    คนสร้างห้องเป็น leader ทันที; ถ้า leader ออกก่อนอีเวนต์จบ ตำแหน่งจะตกไปคนถัดไปตาม `joinedAt`
  - `backend/routes/party.js` (mount ที่ `/api/party`)
    - `GET /api/party` → ห้องที่ฉันอยู่ตอนนี้ (`{ party: null }` ถ้ายังไม่ได้เข้าห้องไหน)
    - `GET /api/party/rooms` → ลิสต์ห้องที่ยังเปิดรับสมาชิกอยู่ (`status: 'open'`) ให้เลือกเข้าร่วม
    - `POST /api/party` → สร้างห้องใหม่จาก party quest — เช็ค `quest.minLevelToHost` ด้วย (ใช้จริงแล้ว ไม่ใช่ dead field)
    - `POST /api/party/join/:partyId`, `POST /api/party/leave` (leave ตอนห้อง completed = แค่ dismiss)
    - **`POST /api/party/complete`** — **เฉพาะหัวหน้าห้องกดได้** ทุกคนในห้อง (รวมหัวหน้า) ได้ P/XP พร้อมกัน
      ล็อกสถานะเป็น `completed` แบบ atomic (`findOneAndUpdate` เช็ค `status: 'open'` ไปด้วย) กันกดซ้ำได้คะแนนซ้ำ
  - **party quest ทำซ้ำได้วันละครั้งต่อคน** (เหมือน quest รายวัน ใช้ตัดเที่ยงคืน JST เดียวกัน) — ใครทำไปแล้ววันนี้
    (ไม่ว่าจะผ่านห้องไหน) จะไม่ได้คะแนนซ้ำถ้าหัวหน้าห้องอื่นกด complete ซ้อน
  - เวลาตัดวันแยกออกมาเป็น `backend/utils/questDay.js` ให้ `routes/quests.js` และ `routes/party.js` เรียกใช้ร่วมกัน
  - `Quest.eventDate` **ถูกลบออกแล้ว** — วันเวลานัดหมายอยู่ที่ `Party.eventDate` (แต่ละห้องนัดคนละเวลากันได้)
    `Quest.location`/`capacity` เหลือไว้เป็นแค่ **ค่า default ให้ฟอร์มสร้างห้องดึงไปเติม**
  - `GET /api/quests` ไม่ส่ง `joinedCount`/`hasJoined` แล้ว (ความหมายเดิมหายไปเพราะไม่มี "เข้าร่วม quest ตรงๆ")
    ส่ง `openPartyCount` (มีกี่ห้องเปิดอยู่) และ `minLevelToHost` แทน
  - ฝั่งแอพ: `PartyProvider` ถือทั้ง "ห้องของฉัน" และ "ลิสต์ห้องให้เลือก" (`lib/providers/party_provider.dart`)
    โหลดทั้งคู่ใน `MainShell.initState` เหมือน quest/achievement
  - **หน้า Explore คือที่เดียวที่เจอ/เข้าร่วมห้องได้** (`lib/pages/explore/explore_page.dart`)
    chip "Party" แสดง **ห้องที่มีคนสร้างไว้แล้ว** เป็น `PartyRoomCard` (`lib/widgets/party_room_card.dart`,
    หน้าตาก็อปแบบ `QuestCard` ให้เหมือนกันเป๊ะเพราะโชว์ปนกันตอนเลือก chip "All") **ไม่ใช่ party quest template
    เหมือนก่อนหน้านี้** — เควส party ตัวเทมเพลตไม่โผล่เป็นการ์ดให้กดในหน้า Explore อีกต่อไป จะเจอได้เฉพาะตอน
    กด + สร้างห้องเท่านั้น ปุ่ม **Create Party (FAB มุมขวาล่าง)** โผล่เฉพาะตอนเลือก chip "Party"
    แผ่น Explore ที่ลากขึ้นจากหน้า Home (`_ExploreSheet` ใน `home_page.dart`) แสดงห้องแบบเดียวกัน แต่ไม่มี FAB
    (ไม่ใช่ `Scaffold` เลยใส่ FAB ไม่ได้ — สร้างห้องได้จากแท็บ Explore เต็มจอเท่านั้น)
  - **หน้า Party เหลือแค่ "ห้องของฉัน"** (`lib/pages/party/party_page.dart`) มี 2 สถานะ:
    1. ยังไม่อยู่ห้องไหน → ป้ายว่าง + ปุ่ม "Browse Parties" พาไปแท็บ Explore
    2. อยู่ห้องที่ `status: open` → การ์ดรายละเอียดห้อง + รายชื่อสมาชิก + **หัวหน้าเห็นปุ่ม "Complete Event"
       ส่วนสมาชิกทั่วไปเห็นแค่ป้าย "Waiting for the leader..."** (ตรงนี้คือจุดที่ `isLeader` เริ่มมีผลกับ UI จริงๆ)
       ทั้งคู่กด "Leave Party" ได้เสมอ; ห้อง `status: completed` → แบนเนอร์สรุปรางวัลค้างไว้ให้เห็นก่อน แล้วกด
       "Back to Parties" (= dismiss ผ่าน `POST /party/leave` ตัวเดิม) ถึงจะไปสร้าง/เข้าร่วมห้องใหม่ได้
  - ✅ **กดชื่อสมาชิกในหน้า Party เปิดโปรไฟล์ได้จริงแล้ว** ไม่ใช่ SnackBar "coming soon" อีกต่อไป
    ทุกแถวกดได้ (ไม่ใช่แค่แถวหัวหน้าเหมือนก่อนหน้านี้) — แถวของ**ตัวเอง** สลับไปแท็บ Profile ของจริง
    ส่วนแถวของ**คนอื่น**เปิด `lib/pages/profile/player_profile_page.dart` (โปรไฟล์แบบดูอย่างเดียว)
    ผ่าน `GET /api/users/:id` (ผู้เล่นที่ login แล้วดูของกันและกันได้ทุกคน ไม่ต้องอยู่ห้องเดียวกัน)
    - `backend/routes/users.js` คัดฟิลด์แบบ **allow-list** เท่านั้น (`displayName level xp points rank`)
      ห้ามใช้ `.select('-password')` เพราะยังหลุด `email`/`resetOtpHash`/`resetOtpExpires` ได้ และไม่ส่ง
      `avatarPath` เพราะเป็น path ในเครื่องคนอื่น เครื่องเราเปิดไม่ได้อยู่ดี
    - progress/stats คำนวณผ่าน `backend/utils/profilePayload.js` (`buildProfileStats`) ตัวเดียวที่
      `GET /auth/me` ก็เรียกใช้ ทั้งสอง endpoint เลยคิดเลขตรงกันเป๊ะ
    - ชิ้นส่วน UI ที่ไม่ผูกกับ "ตัวเอง" (หัวข้อ+แถบ XP, การ์ด Point/Rank, การ์ดสถิติ, ประวัติเควส) ถูกยกออกมา
      เป็น public widget ที่ `lib/widgets/profile_sections.dart` ให้ทั้งหน้า Profile ตัวเองและหน้าโปรไฟล์
      คนอื่นเรียกใช้ร่วมกัน (การ์ด Upgrade Ability ไม่ได้ยกมาเพราะเป็นของตัวเองเท่านั้น)
  - **หน้าสร้างห้องใหม่** `lib/pages/party/create_party_page.dart` (route `/party/create`, เข้าได้ทางเดียว
    คือกด FAB ในหน้า Explore) — เลือกเควส party → กรอกชื่อห้อง/วันเวลา (`showDatePicker`+`showTimePicker`)/
    สถานที่/จำนวนคนรับ (ดึงค่า default จาก quest ให้) สร้างสำเร็จจะ pop กลับพร้อม `true` ให้ Explore
    สลับไปแท็บ Party ให้อัตโนมัติ
  - party quest สำหรับทดสอบ 3 อัน seed ไว้แล้ว (ไม่มี `eventDate` ในไฟล์ seed แล้ว — อันนั้นเป็นของห้อง):
    Community Cleanup, Tree Planting Day, Neighborhood Recycling Drive

### ยังเป็น placeholder / mock ทั้งหมด (มี `// TODO` กำกับในโค้ดแล้ว)
- **การ์ด "Upgrade your Ability"** ในหน้า Profile ยัง mock อยู่ — ยังไม่มี model/endpoint ของ upgrade ฝั่ง backend เลย
- **การแจ้งเตือน** ในหน้า Notification เป็น mock (`mockNotifications` ใน `lib/models/notification_model.dart`) ยังไม่มี endpoint
- **ไอเทมในกระเป๋า (Camera/Fridge)** ยัง mock อยู่ใน `inventory_item_model.dart` — ยังไม่มี `GET /api/inventory`
  (ส่วนเหรียญ Achievement ในหน้าเดียวกันใช้ข้อมูลจริงแล้ว)
  (Camera กับ Fridge คือ **ไอเทมตั้งต้นที่ผู้เล่นทุกคนต้องมี** — ตอนเขียน endpoint จริงต้องแจกให้อัตโนมัติตอนสมัคร ไม่ใช่ของที่ได้จาก quest/reward)

**Route ฝั่ง Flutter** (รวมไว้ที่ `lib/routes/app_routes.dart` ไฟล์เดียว — เพิ่มหน้าใหม่มาแก้ที่นี่):
`/splash`, `/login`, `/register`, `/forgot-password`, `/main` (MainShell + bottom nav),
`/settings`, `/change-password`, `/upgrade-account`, `/notifications`, `/fridge`
> 5 แท็บใน bottom nav ไม่ใช่ route แยก — เป็นหน้าที่สลับกันอยู่ใน `IndexedStack` ของ `MainShell`
> ส่วนหน้าที่ push ทับ (settings / change-password / notifications / fridge) จะไม่มี bottom nav ให้เห็น

**Backend routes ที่มีแล้ว**
- `backend/routes/auth.js` → mount ที่ `/api/auth`:
  `POST /register`, `POST /login`, `POST /guest`, `GET /me`, `POST /upgrade-guest`,
  `POST /verify-password`, `POST /change-password`,
  `POST /forgot-password`, `POST /verify-reset-otp`, `POST /reset-password`
- `backend/routes/quests.js` → mount ที่ `/api/quests`: `GET /`, `GET /history?limit=` , `POST /:id/complete` (ต้อง login ทั้งหมด)
  (`/history` ต้องประกาศก่อน route ที่มี `:id` ไม่งั้นคำว่า history จะถูกจับเป็น id)
- `backend/routes/fridgeItems.js` → mount ที่ `/api/fridge-items`: `GET /`, `POST /`, `DELETE /:id` (ต้อง login ทั้งหมด)
- `backend/routes/achievements.js` → mount ที่ `/api/achievements`: `GET /` (ต้อง login)
- สคริปต์: `npm run seed:quests` (`backend/scripts/seedQuests.js`)

`GET /api/auth/me` คืน 3 ก้อน: `user` (+ level/xp/points/rank), `progress` (ความคืบหน้า level/rank),
`stats` (questCompleted / questTotal / co2SavedKg / partiesJoined — คำนวณจริงจาก `QuestHistory` + `Quest`)

**Backend routes ที่ยังไม่มี (ต้องเขียนเพิ่ม)**: `GET /api/inventory`, Party/Event API, endpoint การแจ้งเตือน

## 6. รายละเอียดปลีกย่อยที่เคยเสียเวลาแก้ปัญหามาก่อน (กันเสียเวลาซ้ำ)

- **Asset path ต้องตรงกับ `pubspec.yaml` เป๊ะๆ ทุกตัวอักษร** ห้ามมี `/` นำหน้า และเปลี่ยน `pubspec.yaml` ต้อง `flutter clean` + full restart เท่านั้น hot reload/restart ไม่พอ
- ⚠️ **ถ้าจะประกาศ asset เป็น "โฟลเดอร์" ใน `pubspec.yaml` ต้องมี `/` ปิดท้ายเสมอ** (เคยพลาดมาแล้ว build พังทั้งแอพ)
  - เขียน `- lib/utils/assets` (ไม่มี `/`) → Flutter มองว่าเป็น**ชื่อไฟล์** พอหาไฟล์นั้นไม่เจอจะขึ้น
    `No file or variants found for asset: lib/utils/assets` แล้ว `Gradle task assembleDebug failed`
  - ตอนนี้ประกาศเป็น **รายไฟล์ทั้งหมด** ไม่ได้ใช้แบบโฟลเดอร์ — เพิ่มรูปใหม่ต้องมาเพิ่มบรรทัดที่นี่ด้วยทุกครั้ง
- รูปพื้นหลัง Profile: `lib/utils/assets/background.png`
- รูป Camera ใน Inventory: `lib/utils/assets/items/camera.png`
- รูป Fridge ใน Inventory: `lib/utils/assets/inventory/fridge.png`
- รูปแจ้งเตือน: `lib/utils/assets/notifications/trophy.png`, `lib/utils/assets/notifications/fridge_expired.png`
- 📦 ไฟล์รูปตอนนี้**ใหญ่มาก (~2 MB ต่อไฟล์)** ทั้งที่แสดงจริงแค่ 72×72 px — ถ้าจะลดขนาดแอพ ย่อเหลือ ~216×216 px ได้เลย
  (เอาไฟล์ที่ย่อแล้วไปทับชื่อเดิม ไม่ต้องแก้โค้ด) ยังไม่ได้ทำ
- **Quantity badge สไตล์ liquid-glass** (ใน `widgets/inventory_card.dart`): 39×16px, สี `#D9D9D9` โปร่งใส 80% (opacity 0.2), มุมโค้ง 20px, drop shadow (Y=4, blur=10, ดำ 50%) — shadow ต้องอยู่คนละ widget layer กับตัวที่ถูก `ClipRRect` ไม่งั้น shadow จะโดนตัดหายไปด้วย
- **กฎ thumbnail ของ `InventoryCard`** (ตั้งใจให้ต่างกัน 2 แบบ อย่าเผลอรวมเป็นแบบเดียว):
  - **มีรูปจริง** (`imageAsset` / `imageFile`) → พื้นโปร่งใส ไม่มีกล่องสีรอง, `BoxFit.contain`,
    และมี**เงาที่วิ่งตามรูปทรงของภาพ** (ก๊อปรูปมาย้อมดำด้วย `srcIn` แล้วเบลอ วางเหลื่อมลง 3px) ไม่ใช่เงาสี่เหลี่ยม
  - **ไม่มีรูป (โชว์ icon)** → ยังใช้กล่องสีอ่อนรอง (`iconColor` opacity 0.1) เหมือนเดิม เพราะ Achievement medal พึ่งลุคนี้อยู่
  - เหตุผลที่แยก: เดิมกล่องสีรองถูกวาดเสมอ ทำให้รูปพื้นหลังโปร่ง (Camera/Fridge ที่ใช้ `iconColor: black87`) มีกรอบเทาติดมาด้วย
- ทดสอบบนเครื่องจริงผ่าน USB ต้องใช้ `adb reverse tcp:5000 tcp:5000` ทุกครั้งที่เสียบสายใหม่ (ไม่ persist ข้าม session)
- ⚠️ **`AppConstants.baseUrl` ต้องสลับค่าตามอุปกรณ์ที่ทดสอบ** (เคยเสียเวลากับเรื่องนี้มาแล้ว — อาการคือ `SocketException: Connection timed out`)
  - **เครื่องจริง + `adb reverse`** → `http://127.0.0.1:5000/api` ← ค่าปัจจุบัน
  - **Android Emulator** → `http://10.0.2.2:5000/api` (`10.0.2.2` เป็น IP พิเศษของ emulator เท่านั้น บนเครื่องจริงไม่มี IP นี้อยู่จริง เลย timeout)
  - เปลี่ยนค่านี้แล้วต้อง **hot restart** ไม่ใช่แค่ hot reload
- ถ้าทดสอบผ่าน WiFi มหาวิทยาลัย/องค์กร อาจเจอ firewall บล็อกการเชื่อม MongoDB Atlas — ใช้ hotspot มือถือแทนได้
- `IndexedStack` ต้องครอบด้วย `SizedBox.expand` ไม่งั้นบางทีไม่ยอมขยายเต็มพื้นที่ (เจอปัญหาช่องว่างสีขาวมาก่อน)
- Gradle JDK ต้องเป็น JDK 17 (ไม่ใช่ JDK ใหม่กว่านี้) ไม่งั้น Gradle sync fail

## 6.5 Deploy backend (ให้แอพใช้ได้โดยไม่ต้องเปิดคอม)

> ❗ **แอพ Flutter รัน Node/Express + MongoDB ในตัวเองไม่ได้** และห้ามฝัง connection string ของ Atlas
> ลงในแอพเด็ดขาด (แกะ APK แล้วได้สิทธิ์เข้าฐานข้อมูลทั้งหมด) — ต้อง deploy backend แล้วให้แอพยิงไปที่ URL นั้น
>
> ทางเลือกที่พิจารณาแล้ว **ตัดทิ้ง**: ต่อ Flutter เข้า Atlas ตรงๆ ผ่าน `mongo_dart` (ไม่ปลอดภัย),
> Atlas Data API (MongoDB ปิดบริการไปแล้วตั้งแต่ 30 ก.ย. 2025)

**เลือกใช้: Render free tier** (ตัดสินใจแล้ว — เลือกเพราะ deploy ง่ายที่สุด)

backend พร้อม deploy แล้ว (ทดสอบว่าบูตด้วย env var อย่างเดียวได้ + health check `GET /` ตอบ 200)
- `backend/package.json` มี `engines.node >= 18`
- `server.js` ใช้ `process.env.PORT` อยู่แล้ว (host กำหนด port ให้เอง **ห้าม hardcode**)
- มี `render.yaml` ที่ root ของ repo — Render อ่านแล้วสร้าง service ให้เอง (`rootDir: backend`)

ขั้นตอน:
1. push โค้ดขึ้น GitHub
2. Render Dashboard → New → Blueprint → เลือก repo นี้
3. กรอก env var 4 ตัวใน dashboard: `MONGODB_URI`, `JWT_SECRET`, `GMAIL_USER`, `GMAIL_APP_PASSWORD`
   (ค่าเดียวกับใน `backend/.env` — ไฟล์นั้นไม่ได้ถูก push ขึ้น git)
4. **MongoDB Atlas → Network Access → เพิ่ม `0.0.0.0/0`** ⚠️ ข้อนี้ลืมบ่อยที่สุด
   cloud host ใช้ IP ไม่ตายตัว ถ้าไม่เปิดจะ connect ไม่ได้แล้ว process ตายวนไป
5. เอา URL ที่ได้ไปใส่ `_deployedApiUrl` ใน `lib/utils/constants.dart` (**ต้องมี `/api` ต่อท้าย**) แล้ว build แอพใหม่

⚠️ **ข้อจำกัด free tier: service หลับหลังไม่มีคนใช้ ~15 นาที คำขอแรกหลังหลับช้า 30-60 วิ**
- `AuthProvider.checkSession()` เลย **จงใจไม่ await `refreshProfile()`** — ไม่งั้นหน้า splash จะค้างรอ
  จนกว่า backend จะตื่น ตอนนี้เข้าแอพด้วยค่าที่ cache ไว้ก่อน แล้วตัวเลขค่อยอัปเดตเอง **อย่าเผลอใส่ `await` กลับเข้าไป**
- ส่วนอื่นยังไม่ได้ใส่ timeout ให้ http request — ถ้าเจอปัญหาค้างนานตอน cold start ค่อยมาเพิ่มทีหลัง

### seed quest ตอน server boot
`server.js` เรียก `seedQuests()` ทุกครั้งที่ backend สตาร์ท (upsert อิง `title` เลยรันซ้ำได้ ไม่สร้างของซ้ำ)
มีไว้เพราะบางเน็ต เช่น **wifi มหาลัย ต่อ MongoDB Atlas จากเครื่องตัวเองไม่ได้** (ไม่อยู่ใน IP whitelist)
เลยรัน `npm run seed:quests` เองไม่ได้ → ให้ server บน Render seed ให้แทนตอน deploy
ปิดได้ด้วย env `SEED_QUESTS_ON_BOOT=false` และ seed พังจะไม่ทำให้ API ล่ม (แค่ log warning)
เดียวกันตอน boot ยังล้าง `PartyMember` รุ่นเก่าที่ผูกกับ `questId` ตรงๆ (ก่อนมีห้อง/`Party` แยก) ทิ้งด้วย
(idempotent รันซ้ำได้) party quest ในไฟล์ seed **ไม่มี `eventDate` แล้ว** เพราะวันเวลานัดหมายย้ายไปอยู่ที่
`Party.eventDate` ของแต่ละห้องแทน (ผู้เล่นกรอกเองตอนสร้างห้อง) — restart ถี่แค่ไหนก็ไม่กระทบวันที่ในห้องที่มีอยู่แล้ว

## 7. งานถัดไปที่แนะนำ (เรียงตามลำดับที่ควรทำ)

1. เขียน backend routes สำหรับ Inventory แล้วต่อเข้ากับหน้า Inventory
   — Achievement ทำได้แล้วตอนนี้ เพราะ `QuestHistory` เริ่มมีข้อมูลจริงให้เอาไปเช็คเงื่อนไขปลดล็อก medal
2. endpoint การแจ้งเตือน แทน `mockNotifications` (ยังไม่มี model ฝั่ง backend เลย)
3. การ์ด "Upgrade your Ability" ในหน้า Profile ยัง mock อยู่ — ยังไม่มี model/endpoint ฝั่ง backend เลย
