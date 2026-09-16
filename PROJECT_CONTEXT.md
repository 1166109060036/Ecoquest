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
- **แก้ไขชื่อที่แสดง** — เมนู "Edit Display Name" ในหน้า Settings (ใช้ได้ทั้ง guest และบัญชีปกติ) เปิด
  dialog กรอกชื่อใหม่ → `POST /auth/display-name` จำกัดไม่เกิน 20 ตัวอักษร, ห้ามว่าง
- **เปิด/ปิดการแจ้งเตือน** — toggle switch ในหน้า Settings → `POST /auth/notification-preference`
  เก็บที่ `User.notificationsEnabled` (default true) ปิดแล้วแค่หยุด**สร้าง**แจ้งเตือนใหม่ (เควสสำเร็จ/
  เหรียญปลดล็อก/ของใกล้หมดอายุ) ที่จุดเดียวคือ `backend/utils/notifications.js#createNotification`
  — ใบที่มีอยู่แล้วในลิสต์ก่อนปิดไม่ถูกลบ ยังโชว์เหมือนเดิม
- **About** — เมนูในหน้า Settings โชว์ชื่อแอพ + เวอร์ชัน (`AppConstants.appVersion`, ต้องแก้เองให้ตรงกับ
  `pubspec.yaml` ทุกครั้งที่ bump เวอร์ชัน เพราะยังไม่ได้เพิ่ม dependency `package_info_plus`) — เป็น UI
  ล้วนๆ ไม่มี backend
- **เอฟเฟคใบไม้ลอยตก** — `FallingLeavesOverlay` widget (`lib/widgets/falling_leaves_overlay.dart`) วาด
  ด้วย `CustomPainter` ตัวเดียว (ไม่ใช่ widget แยกต่อใบ) ผูกกับ `AnimationController` ที่ `repeat()` วนไม่รู้จบ
  — ใส่ไว้ในทุกหน้าที่มีพื้นหลังธีม (background.png + gradient มืดทับ): Profile (รวม Home เพราะ Home เอา
  ProfilePage ไปใช้เป็นพื้นหลัง), Player Profile, Party, Create Party, Settings, Change Password,
  Upgrade Account — วางไว้ระหว่าง gradient กับเนื้อหาจริงใน `Stack` เสมอ (ดูตัวอย่างที่
  `lib/pages/profile/profile_page.dart`) ให้ใบไม้ลอยอยู่หลังการ์ด/ปุ่ม ไม่บังตัวหนังสือ
  ⚠️ หน้าที่ธีมสว่าง/ไม่ได้ใช้พื้นหลัง gradient แบบนี้ (เช่น `quest_detail_page.dart`, หน้า auth ทั้งหมด)
  **ไม่ได้ใส่** ไว้ตั้งใจ เพราะไม่เข้ากับธีมสว่างของหน้านั้น
- **ระบบเสียง — ใช้งานได้จริงแล้ว** (ผู้ใช้อัปโหลดไฟล์เสียงเข้ามาเองแล้ว ไม่ใช่แค่ช่องเปล่าอีกต่อไป) —
  `lib/services/sound_service.dart` เป็นเจ้าของการเล่นเสียงทั้งหมด: `playBackgroundMusic()` (เล่นวนตั้งแต่
  เปิดแอพ เรียกใน `main()`), `playClick()` (เล่นเฉพาะตอนแตะ widget ที่กดได้จริงๆ เช่นปุ่ม/`InkWell`/
  `ListTile` ผ่าน `SoundSplashFactory` — คลาสท้ายไฟล์ `sound_service.dart` ที่ override
  `ThemeData.splashFactory` ใน `lib/main.dart` (`splashFactory: SoundSplashFactory(InkRipple.splashFactory)`)
  แทนที่จะเป็น `Listener` ครอบทั้งแอพแบบเดิม — widget ที่กดได้แทบทุกตัวในแอพสร้าง ink splash ผ่าน
  `Theme.splashFactory` ตัวเดียวกันเสมอ ครอบตรงนี้ที่เดียวเลยดักได้ทุกปุ่มทั่วแอพโดยไม่ต้องแก้ทีละไฟล์
  ส่วนพื้นที่ว่าง/การลาก scroll (ไม่มี ink splash) จะไม่มีเสียง ตรงตามที่ต้องการ
  ⚠️ **ข้อจำกัด**: widget ที่ทำปุ่มเองด้วย `GestureDetector` ตรงๆ โดยไม่ผ่าน `InkWell`/`Material` จะไม่มี
  ink splash เลยไม่มีเสียงตามไปด้วย — ถ้าเจอจุดแบบนี้ที่ควรมีเสียงแต่ไม่มี ต้องเพิ่มเรียก `playClick()`
  ตรงๆ เฉพาะจุดนั้นแทน)
  - ไฟล์เสียงอยู่ที่ `lib/utils/assets/sounds/background_music.mp3` และ `button_click.mp3` (ดู README.md
    ในโฟลเดอร์นั้น) ประกาศเป็นโฟลเดอร์ไว้ใน `pubspec.yaml` แล้ว (แนวเดียวกับ `items/`/`questimg/`)
  - **ปรับระดับเสียงแยกกันได้ในหน้า Settings** — สไลเดอร์ "Background Music" กับ "Sound Effects" คนละใบ
    (`_VolumeSliderItem` ใน `lib/pages/settings/settings_page.dart`) เก็บค่าไว้ผ่าน `SharedPreferences`
    เอง (`sound_music_volume`/`sound_click_volume`) ไม่ผูกกับ backend/User model เพราะเป็นการตั้งค่าของ
    เครื่องล้วนๆ ไม่ต้อง sync ข้ามเครื่อง — โหลดค่าที่เคยตั้งไว้กลับมาใช้ตอนเปิดแอพผ่าน
    `SoundService.loadSavedVolumes()` (ต้องเรียก**ก่อน** `playBackgroundMusic()` ใน `main()` เสมอ ไม่งั้น
    เพลงจะดังสุดวูบนึงก่อนค่อยปรับลง) — ลากสไลเดอร์ตอนอยู่ระหว่างลาก (`onChanged`) ใช้ `persist: false`
    ปรับเสียงสดให้ได้ยินทันทีแต่ไม่เขียนดิสก์ทุกเฟรม ค่อยเขียนจริงตอนปล่อยนิ้ว (`onChangeEnd`)
  - ⚠️ **ข้อควรรู้ตอนแก้ไฟล์นี้ต่อ**:
    - `AudioPlayer` แต่ละตัวจับค่า `AudioCache.instance` ไปเก็บเป็นของตัวเองตอนสร้างออบเจกต์ (field
      initializer รันก่อน constructor body เสมอ) — ห้ามแก้ `AudioCache.instance` ตรงๆ ใน constructor
      ของ `SoundService` เพราะจะช้าไปแล้ว ต้อง assign `.audioCache` ให้แต่ละ `AudioPlayer` ตรงๆ แทน
      (ดูคอมเมนต์ในไฟล์) — ใช้ `AudioCache(prefix: '')` เพราะ asset ของโปรเจคนี้ไม่ได้อยู่ใต้โฟลเดอร์
      `assets/` (default prefix ของ audioplayers) แต่อยู่ใต้ `lib/utils/assets/` ตามที่ `pubspec.yaml`
      ประกาศไว้จริง
    - เดิมเคยลองใช้ `PlayerMode.lowLatency` (SoundPool) กับเสียงคลิก แต่ SoundPool บน Android decode
      mp3 ที่มี ID3 tag (เช่นไฟล์ export จาก LAME) ไม่ผ่านแบบเงียบๆ ไม่มี error เลย — เปลี่ยนกลับมาใช้
      `PlayerMode.mediaPlayer` (ค่า default) แทนแล้ว รองรับฟอร์แมตได้กว้างกว่ามาก
    - ค่า default ของ audioplayers คือขอ Android audio focus แบบ `gain` (ผูกขาด) ทุกครั้งที่ `play()`
      ถูกเรียก — ทำให้ player อีกตัวในแอพเดียวกัน (เช่นเพลงพื้นหลังตอนกดปุ่ม) โดน pause ไปเงียบๆ ต้องตั้ง
      `AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)` ให้ทั้งคู่เสมอ ถึงจะเล่นซ้อนกัน
      ได้โดยไม่แย่งกันเอง (ดู `_mixContext` ในไฟล์)
  - ทุกเมธอดใน `SoundService` ดัก error เงียบๆ (ไม่ throw ต่อ, มี `debugPrint` ให้เห็นตอนรัน `flutter run`
    เท่านั้น) — ไม่มีไฟล์เสียงก็รันแอพได้ปกติทุกอย่างเหมือนเดิม แค่ไม่มีเสียง (แนวเดียวกับ `errorBuilder`
    ที่ `InventoryCard` ใช้ตอนหารูปไอเทมไม่เจอ)
- **Popup ยืนยัน/แจ้งเตือนทั้งแอพ — ธีม "Liquid Glass" แบบ macOS** — `LiquidGlassDialog` +
  `LiquidGlassAction` (`lib/widgets/liquid_glass_dialog.dart`) เป็น widget กลางที่ใช้แทน `AlertDialog`
  ธรรมดาทุกจุดในแอพที่ผู้เล่นเจอ ให้หน้าตาเหมือนกันหมด: กระจกฝ้าโปร่งแสง (`BackdropFilter` เบลอพื้นหลัง
  จริงๆ ไม่ใช่แค่สีขาวโปร่งแสงเฉยๆ), ขอบมน 28px, เส้นไฮไลท์บางๆ พาดขอบบนจำลองแสงสะท้อนบนผิวกระจก, ปุ่ม
  action ทรงแคปซูล (`LiquidGlassAction` — ไม่ใส่สี = ปุ่มรอง/กระจกใสจางๆ, ใส่สี = ปุ่มหลัก/อันตราย fill เต็ม)
  - เปิดผ่าน `LiquidGlassDialog.show<T>(context: ..., title: ..., content: ..., actions: [...])`
    (คืนค่าเหมือน `showDialog` ปกติทุกอย่าง — เอา build จุดเดิมออก เปลี่ยนแค่ตัวเรียก)
  - ใช้อยู่ที่: ลบของในตู้เย็น (`fridge_page.dart`), Edit Display Name/About/Log out
    (`settings_page.dart`), Leave Party/Complete Event (`party_page.dart`), Use Super Energy confirm
    (`inventory_page.dart`), ลบรูป EcoQuest Moment (`camera_page.dart`), popup ยินดีได้เหรียญใหม่
    (`utils/quest_completion.dart`)
  - ⚠️ **ไม่ได้ใส่ที่หน้า Admin** (`admin_page.dart`) — ตั้งใจให้หน้านั้นใช้ธีม Material เรียบๆ แยกจาก
    เกมจริงอยู่แล้ว (ดูคอมเมนต์บนสุดของไฟล์) ใส่ liquid glass เข้าไปจะขัดกับการตั้งใจนั้น
  - ⚠️ ไม่ได้ใส่ที่ popup ดูรูปเต็มจอใน `camera_page.dart` (`_openPhoto`) เพราะเป็นตัวโชว์รูปเต็มจอ
    ไม่ใช่ popup ยืนยัน/แจ้งเตือนแบบเดียวกัน
- **ระบบเคลื่อนไหว/เอฟเฟคทั่วแอพ — ✅ ทำครบทั้ง 4 Phase แล้ว** (แผนเต็มอยู่ที่
  `C:\Users\parto\.claude\plans\wild-knitting-nova.md`) ผู้ใช้เลือกมา 11 อย่างจากเมนูที่เสนอไป
  - **widget กลางใหม่ใต้ `lib/widgets/`** (Phase 1): `staggered_fade_in.dart` (`FadeSlideIn` — ยกมาจาก
    `_FadeSlideIn` เดิมใน `fridge_page.dart` เพิ่ม `delay` ให้ใช้กับลิสต์ได้), `pressable_scale.dart`
    (`PressableScale` — ใช้ `Listener` ไม่ใช่ `GestureDetector` ตั้งใจ กันแย่ง gesture arena กับ
    `InkWell`/เสียงคลิก), `particle_burst.dart` (`ParticleBurstOverlay`/`showParticleBurst()` — burst
    อนุภาคแบบ one-shot ทำเองด้วย `CustomPainter` ตามแพทเทิร์นเดียวกับ `falling_leaves_overlay.dart`
    ไม่ใช้ package `confetti`), `count_up_text.dart` (`CountUpNumber` — ใช้ `formatNumber()` เดิมจาก
    `profile_sections.dart`), `pulse_glow.dart` (`PulseGlow`), `skeleton_box.dart` (`SkeletonBox` +
    `InventoryCardSkeleton`/`QuestCardSkeleton`), `leaf_refresh_indicator.dart` (`LeafRefreshIndicator`
    — ใช้ package `custom_refresh_indicator` ที่เพิ่มใน `pubspec.yaml`, ยังไม่ได้เอาไปแทน `RefreshIndicator`
    จุดไหนจริง รอ Phase 4), `breathing_icon.dart` (`BreathingIcon`)
  - **`LiquidGlassDialog` เพิ่ม param `backgroundEffect`** (optional, วาดเป็นชั้นแรกสุดใน Stack หลังไอคอน/
    ข้อความ แต่ยังโดน `ClipRRect(28)` ตัดขอบเหมือนเดิม) — ใช้ใส่ `ParticleBurstOverlay` ตอนฉลอง
  - **เอฟเฟคฉลอง (Phase 2)** ทั้งหมดอยู่ใน `handleQuestCompleted()` (`utils/quest_completion.dart`):
    ยิง `showParticleBurst()` ทุกครั้งที่จบเควส/อีเวนต์ปาร์ตี้ (คู่กับ SnackBar เดิม), เช็คเลเวลอัพโดยเก็บ
    `levelBefore` **ก่อน** เรียก `authProvider.refreshProfile()` เสมอ (สำคัญ — `refreshProfile()` แทนที่
    `_profile` ทั้งก้อน อ่านทีหลังจะเจอค่าใหม่ทั้งคู่) ถ้าเลเวลขึ้นจริงเปิด popup ใหม่ `_showLevelUpDialog`
    (คนละหน้าตากับ popup เหรียญ — สีเขียว/อนุภาคเยอะกว่า) เรียง**เหรียญก่อนเลเวลอัพ**ถ้าเกิดพร้อมกัน —
    popup เหรียญเดิมก็เพิ่ม `backgroundEffect` (ประกายเบาๆ) และห่อไอคอนถ้วยรางวัลด้วย `_BounceIn`
    (`Curves.elasticOut`) ให้เด้งเข้ามาแทนโผล่มาเฉยๆ
  - **ตัวเลข Points/XP นับไล่ขึ้น** — `CountUpNumber` แทน `Text` ธรรมดาใน `UserHeader`/`PointsAndRankCard`
    (`profile_sections.dart`) นับขึ้นเองอัตโนมัติทุกครั้งที่ provider รีเฟรชค่าใหม่ ไม่ต้อง wiring เพิ่ม
  - **เอฟเฟคซื้อของสำเร็จ** — `InventoryCard` เพิ่ม param `celebrate: bool` (ห่อ thumbnail ด้วย
    `PulseGlow`) `ShopPage` แปลงเป็น `StatefulWidget` เก็บ `_celebratingItemType` เคลียร์เองหลัง 600ms;
    `_UpgradeAbilityCard` ใน `profile_page.dart` ก็แปลงเป็น `StatefulWidget` แบบเดียวกัน (เก็บ
    `_celebratingUpgradeType`) ห่อไอคอน upgrade ที่เพิ่งซื้อด้วย `PulseGlow`
  - **การเคลื่อนไหวพื้นฐานทั่วแอพ (Phase 3)** เสร็จแล้ว:
    - **ลิสต์ไล่โผล่ทีละใบ** — ห่อแต่ละ item ด้วย `FadeSlideIn(key: ValueKey(id เสถียร), delay: 40ms*index)`
      ที่: ลิสต์เควส/ห้องปาร์ตี้ผสมกันใน `explore_page.dart`, ลิสต์ไอเทมใน `inventory_page.dart`/
      `shop_page.dart`, ลิสต์แจ้งเตือนใน `notification_page.dart`, แถวสมาชิกปาร์ตี้ใน `party_page.dart`
      (ทั้ง `_PartyView` และ `_CompletedView`) — ⚠️ ต้อง key ด้วย id จริง (ไม่ใช่ index) เสมอ ไม่งั้น
      Flutter อาจ reuse state ผิดตัวตอนลิสต์เรียงลำดับใหม่/สั้นลง
    - **แถบเมนูล่างมีเอฟเฟคสลับแท็บ** — `AppBottomNavBar` (`bottom_nav_bar.dart`) ห่อไอคอนด้วย
      `AnimatedScale` (ใหญ่ขึ้นเบาๆ ตอน active) และไล่สีไอคอน/ตัวหนังสือด้วย `TweenAnimationBuilder<Color?>`
      แทนสลับสีวูบเดียว — ⚠️ ใช้ `TweenAnimationBuilder` ไม่ใช่ `AnimatedDefaultTextStyle` กับตัว `Icon`
      เพราะ `AnimatedDefaultTextStyle` มีผลแค่ widget ที่อ่านค่าจาก `DefaultTextStyle` เท่านั้น (ข้อความ)
      ไม่มีผลกับสี icon เลย
    - **ปุ่มยุบตัวตอนกด** — ห่อด้วย `PressableScale` (Phase 1) ที่ปุ่มหลักเกือบทั้งหมด: `_GateButton`/
      "Back to Parties" ใน `party_page.dart`, `LiquidGlassAction`, ปุ่มซื้อ upgrade ใน `profile_page.dart`,
      ปุ่ม action ใน `quest_card.dart`/`inventory_card.dart`, ปุ่ม Join ใน `party_room_card.dart`
  - **ฟีดแบ็กแบบเรียลไทม์/สถานะ (Phase 4)** เสร็จแล้ว:
    - **ปุ่ม Complete/Start ปาร์ตี้กระพริบตอนพร้อมกด** — `_GateButton` (`party_page.dart`) แปลงจาก
      `StatelessWidget` เป็น `StatefulWidget` เทียบ `enabled` เก่า/ใหม่ใน `didUpdateWidget` (ทำงานได้
      เพราะไม่มี Key และถูก rebuild ทุกวินาทีจาก `_ticker` เดิม) ตอน false→true เล่น `PulseGlow` รอบปุ่ม
    - **หน้า Loading เป็น skeleton แทนวงกลมหมุน** — ที่: `inventory_page.dart`, `shop_page.dart`,
      `notification_page.dart`, `eco_badge_page.dart` (ใช้ `InventoryCardSkeleton`), explore sheet ใน
      `home_page.dart` (ใช้ `QuestCardSkeleton`), `party_page.dart` (widget ใหม่ `_PartyLoadingSkeleton`
      ในไฟล์เดียวกัน — การ์ดอีเวนต์ + แถวสมาชิกคร่าวๆ)
    - **Pull-to-refresh ใบไม้หมุน** — สลับ `RefreshIndicator` ปกติเป็น `LeafRefreshIndicator` (Phase 1,
      สร้างบน package `custom_refresh_indicator`) ที่: `profile_page.dart` (`_MaybeRefreshable`),
      `inventory_page.dart`, `shop_page.dart`, `eco_badge_page.dart`, `notification_page.dart`
    - **Empty state หายใจเบาๆ** — ห่อไอคอนด้วย `BreathingIcon` ที่: `inventory_page.dart`,
      `shop_page.dart`, `notification_page.dart`, `eco_badge_page.dart`, `explore_page.dart`,
      `party_page.dart` (`_NoPartyState`)
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
  - ✅ **Season เปิด/ปิดอัตโนมัติแล้ว ไม่ต้อง seed มือ** — `backend/utils/seasons.js#ensureActiveSeason()`
    เช็คทุกครั้งที่มีคนเรียก `GET /auth/me` (ผ่าน `utils/profilePayload.js`) และตอน server boot
    ยังไม่เคยมี season เลย → เปิด season 1 ให้เอง / season ปัจจุบันหมดอายุ (`endDate` ผ่านไปแล้ว) →
    ปิดแล้วเปิดอันถัดไปให้เอง ยาวซีซั่นละ 90 วัน (`SEASON_DURATION_DAYS` ในไฟล์เดียวกัน)
    - หน้า Profile (ทั้งของตัวเองและของผู้เล่นคนอื่น) โชว์ "Season N · D days left" ใต้แถบ Rank ด้วยแล้ว
    - กันสอง request ปิด/เปิดซีซั่นชนกันพอดีตอนหมดอายุด้วย compare-and-swap แบบเดียวกับ
      latch ที่ `routes/party.js` ใช้กันคะแนนซ้ำ — ถ้าไม่มีคนเข้าแอพนานจนซีซั่นหมดอายุไปหลายรอบ
      จะไล่เปิด-ปิดทีละซีซั่นจนกว่าจะถึงซีซั่นที่ยัง cover เวลาปัจจุบัน ไม่กระโดดข้ามเลข
    - `npm run seed:season` **ยังอยู่แต่ไม่จำเป็นต้องรันแล้ว** เหลือไว้บังคับสร้าง/รีเซ็ต season ตอน
      dev/debug เท่านั้น (มีคำเตือนในตัวสคริปต์ว่าจะไปทับ season 1 ถ้าระบบหมุนไปไกลกว่านั้นแล้ว)
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
- **รูปโปรไฟล์ (avatar) อัปโหลดขึ้น server จริงแล้ว** — แตะที่ avatar ในหน้า Profile (`UserHeader` ใน
  `lib/widgets/profile_sections.dart`) เปิด bottom sheet ให้ถ่ายรูป / เลือกจากคลังรูป / ลบรูป
  (ลบโชว์เฉพาะตอนมีรูปอยู่แล้ว)
  - เก็บเป็น `Buffer` ใน MongoDB โดยตรง (`User.avatarData` + `avatarContentType` + `avatarUpdatedAt`)
    **ไม่เก็บเป็นไฟล์บน disk ของ server** เพราะ Render free tier เป็น ephemeral filesystem
    (ไฟล์ที่เขียนไว้หายทุกครั้งที่ deploy/restart ใหม่)
  - อัปโหลด: อ่านรูปเป็น bytes ฝั่งแอพ (`XFile.readAsBytes()`) แล้ว base64 ส่งเข้า `POST /api/auth/avatar`
    (body `{avatarBase64, contentType}`, ส่ง `avatarBase64: null` เพื่อลบ) — จำกัดไม่เกิน 4MB และรับแค่
    `image/jpeg`/`image/png` เท่านั้น (`backend/routes/auth.js`)
  - ดึงรูป: `GET /api/users/:id/avatar` เสิร์ฟ `avatarData` ตรงๆ เป็น response — เก็บ URL ไว้เป็น
    `avatarUrl` (path สั้นๆ `/users/:id/avatar?v=<timestamp>`) สร้างจาก **`backend/utils/avatar.js`**
    (`avatarUrlFor`) ไฟล์เดียว ที่ query string `?v=` ต่อท้ายคือ cache-buster ผูกกับ `avatarUpdatedAt`
    กัน Flutter cache รูปเก่าค้างหลังเปลี่ยน avatar
  - ⚠️ **route เสิร์ฟรูปจงใจไม่ใส่ authMiddleware** (public) เพื่อให้ `Image.network()` เรียกตรงได้โดยไม่ต้องแนบ
    token — ยอมรับความเสี่ยงนี้เพราะเดา URL ได้ยาก (ต้องรู้ ObjectId 24 ตัวอักษร) และไม่มีข้อมูลอ่อนไหวอื่น
    นอกจากรูปโปรไฟล์
  - ทุก route ที่ query `User` แบบเต็ม (ไม่เกี่ยวกับรูป) ต้อง `.select('-avatarData')` เสมอ ไม่งั้นจะลาก Buffer
    รูปเข้า memory โดยไม่จำเป็น (โดยเฉพาะ loop วนหลายคนอย่างตอนปิดปาร์ตี้ควิซ์ใน `routes/party.js`)
  - ตอนนี้แสดง avatar ของ**คนอื่น**ได้แล้วทุกที่ที่มีรูปคนอื่นโชว์ (หน้ารายชื่อสมาชิกปาร์ตี้ `party_page.dart`,
    หน้าโปรไฟล์สาธารณะ `player_profile_page.dart`) เพราะ URL ชี้ไปที่ server ไม่ใช่ path ในเครื่องอีกต่อไป
  - `AppConstants.resolveUrl()` (`lib/utils/constants.dart`) เป็นจุดเดียวที่เติม `baseUrl` นำหน้า
    `avatarUrl` ที่ backend ส่งมา — เช็ค `startsWith('http')` ก่อนเสมอ กัน URL ถูกเติม `baseUrl` ซ้ำสอง
    ตอนโหลดค่าที่ cache ไว้ใน `SharedPreferences` กลับมา (`UserModel.toJson()` cache ค่าที่เติม prefix แล้ว)
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
- **Inventory ใช้ข้อมูลจริงแล้ว** — `GET /api/inventory` แจกไอเทมตั้งต้น Camera/Fridge ให้อัตโนมัติ
  (แบบ lazy ตอนอ่านครั้งแรก ไม่ใช่ตอนสมัคร — บัญชีเก่าที่มีอยู่ก่อนฟีเจอร์นี้ก็ได้ของไปด้วยโดยไม่ต้อง backfill DB)
  นิยามไอเทมอยู่ที่ `backend/utils/inventory.js` (แนวเดียวกับ `MEDALS` ใน `utils/achievements.js`)
  ฝั่งแอพแปลง `itemType` เป็นไอคอน/สีเองผ่าน `InventoryItemModel` (`lib/models/inventory_item_model.dart`)
  - **ไอเทม Energy (ซื้อได้/ใช้ได้จริง)** — Red/Blue/Green/Super Energy ต่างจาก Camera/Fridge ตรงที่มี
    `cost` (ซื้อด้วย Points) และ `effect` (ใช้แล้วได้ผลจริง) ใน `ITEMS` catalogue:
    - **Red Energy** (40P) — 2x Points จากทุกเควส นาน 30 นาที
    - **Blue Energy** (40P) — 2x XP จากทุกเควส นาน 30 นาที
    - **Green Energy** (40P) — 2x Points จากเควส Party เท่านั้น นาน 30 นาที
    - **Super Energy** (100P) — ลบประวัติเควสที่ทำวันนี้ทั้งหมด (`QuestHistory` ที่ `completedAt >= startOfToday()`)
      ทำให้ `completedToday`/gate เควสรายวันกลับมาทำได้อีกรอบทันที — แต้ม/XP ที่ได้ไปแล้วไม่ถูกหักคืน
    ⚠️ ราคา/ตัวคูณยังไม่ผ่านการเทสสมดุลเกมจริง ปรับได้ที่เดียวที่ `ITEMS` ใน `utils/inventory.js`
  - `POST /api/inventory/:itemType/buy` — ซื้อ 1 ชิ้นด้วย Points (atomic compare-and-swap แบบเดียวกับ
    `buyUpgrade` ใน `utils/upgrades.js`) — ไม่จำกัดจำนวนซื้อซ้ำ (ต่างจาก upgrade ที่มี `maxLevel`)
  - `POST /api/inventory/:itemType/use` — ใช้ 1 ชิ้น หักจำนวนแบบ atomic ก่อนเสมอแล้วค่อยใส่ผล (กันกดรัวๆ
    ได้ผลฟรีโดยไม่เสียของจริง) — Red/Blue/Green ตั้งค่า `redEnergyExpiresAt`/`blueEnergyExpiresAt`/
    `greenEnergyExpiresAt` บน `User` (`backend/models/User.js`) เป็นตอนนี้ + 30 นาที
  - **`withEnergyBoosts(bonuses, user)`** (`utils/inventory.js`) — จุดเชื่อมกับระบบ upgrade เดิม: เติม
    เปอร์เซ็นต์โบนัสจากบัฟ Energy ที่ยังไม่หมดอายุเข้าไปใน `bonuses` (จาก `getUserBonuses`/`getUserBonusesMap`
    ใน `utils/upgrades.js`) ก่อนส่งเข้า `applyBonuses` ตามปกติ — ไม่ต้องแก้ `applyBonuses` เลยเพราะมันรับแค่
    ตัวเลขเปอร์เซ็นต์อยู่แล้ว (บวก 100 = คูณ 2 เท่า) เรียกที่ 3 จุด: `GET /api/quests` (preview การ์ดเควส),
    `POST /api/quests/:id/complete` (เควสเดี่ยว), `POST /api/party/complete` (เควส party ในลูปแจกรางวัล
    ต่อสมาชิก — ใช้ `user` ที่โหลดสดในลูปอยู่แล้ว ไม่ query ซ้ำ)
  - ฝั่งแอพ: ปุ่ม **"Use"** อยู่ในการ์ดไอเทมที่หน้า **Inventory** (เฉพาะไอเทมที่มีอยู่จริง `quantity > 0`
    เท่านั้น — ไอเทมซื้อได้ที่ยังไม่เคยซื้อไม่โชว์ที่นี่) ส่วนซื้อของอยู่ที่หน้า **Item Shop แยกต่างหาก**
    (`lib/pages/shop/shop_page.dart`) เข้าจากปุ่มร้านค้า (`Icons.storefront`) ข้างปุ่มกระดิ่งแจ้งเตือนมุมขวาบน
    ของหน้า Profile — หน้าตาอิงตาม Inventory ทั้งหมด (พื้นหลังเทาอ่อน, การ์ดแบบเดียวกัน) ต่างกันแค่ปุ่มขวา
    เป็น "Buy · [ราคา] P" แทน "Use" (ใช้ `InventoryCard` ตัวเดิม, ปุ่ม disable เองถ้าแต้มไม่พอ) ใช้
    `InventoryProvider.items` ชุดเดียวกับ Inventory กรองเอาแค่ไอเทมที่มี `cost` — ไม่มี endpoint แยกสำหรับ
    ร้านค้า เพราะ `GET /api/inventory` ส่งไอเทมซื้อได้ทุกอันมาเสมอ (แม้ `quantity: 0`) อยู่แล้ว
    (**เดิมเคยฝังเป็นการ์ด "Energy Shop" อยู่ในหน้า Profile โดยตรง แต่ย้ายออกมาเป็นหน้าแยกแล้วตามที่ขอ**)
  - **ช่องรูปไอเทม Energy/Eco Badge** — `InventoryItemModel.imageAsset` เว้นชื่อไฟล์ไว้ล่วงหน้าแล้วสำหรับ
    ทั้ง 4 สี Energy (`lib/utils/assets/items/red_energy.png` ฯลฯ) และ `eco_badge.png` แม้ยังไม่มีไฟล์จริง
    — `pubspec.yaml` ประกาศ `lib/utils/assets/items/` เป็นโฟลเดอร์ไว้แล้ว (แนวเดียวกับ `questimg/`) วางไฟล์
    รูปชื่อตรงกันได้เลยไม่ต้องแก้โค้ด/pubspec เพิ่ม ระหว่างที่ยังไม่มีไฟล์ `InventoryCard` จะ fallback ไปโชว์
    icon/สีเดิมแทนเองอัตโนมัติ
- **Eco Badge — ที่เก็บเหรียญ Achievement** — ไอเทมตั้งต้นอันที่ 3 (starter, คู่กับ Camera/Fridge) ใน
  `ITEMS` (`backend/utils/inventory.js`) กดไอเทมนี้ในหน้า Inventory แล้วเปิดไป **`EcoBadgePage`**
  (`lib/pages/inventory/eco_badge_page.dart`, route `/eco-badge`) เหมือนที่ไอเทม Fridge เปิดไป
  `FridgePage` — โชว์เฉพาะเหรียญที่ **ปลดล็อกแล้ว** เท่านั้น (`AchievementProvider.unlocked`) เรียงล่าสุด
  ขึ้นก่อนตาม `unlockedAt` ไม่โชว์เหรียญที่ยังล็อกอยู่ (ไอเทมนี้เป็น "ที่เก็บ" ของที่ทำสำเร็จแล้วเท่านั้น
  ไม่ใช่หน้ารวมความคืบหน้าทั้งหมด) ⚠️ ย้ายเหรียญออกจากลิสต์รวมในหน้า Inventory เดิมมาไว้ที่นี่ทั้งหมดแล้ว
  (ก่อนหน้านี้ Inventory โชว์ไอเทม+เหรียญปนกันในลิสต์เดียว ตอนนี้ Inventory โชว์แค่ไอเทมอย่างเดียว)
- **ระบบแจ้งเตือนใช้งานได้จริงแล้ว** — `GET /api/notifications` + จุดแดงบนกระดิ่งในหน้า Profile
  แจ้งเตือน 3 แบบ: ทำเควสสำเร็จ, ของในตู้เย็นใกล้หมดอายุ/หมดอายุแล้ว, ปลดล็อกเหรียญ Achievement
  - `backend/utils/notifications.js` มี `dedupeKey` กันสร้างซ้ำ (unique index `userId+dedupeKey`)
    ต้อง `$setOnInsert` เท่านั้น ไม่ใช่ `$set` ไม่งั้นแถวที่อ่านไปแล้วจะโดนรีเซ็ตกลับเป็นยังไม่อ่าน
  - ⚠️ **แจ้งเตือนของใกล้หมดอายุสร้างแบบ lazy ตอนเรียก `GET /api/notifications`** เพราะ backend
    ไม่มี scheduler/cron เลยสักตัว และ Render free tier หลับเมื่อไม่มีคนใช้ พึ่ง cron จริงไม่ได้
  - เควสสำเร็จ (ทั้ง solo และ party fan-out ตอนหัวหน้ากดจบอีเวนต์) กับปลดล็อกเหรียญ สร้างตอนเกิดเหตุการณ์จริง
    จุดปลดล็อกเหรียญรวมไว้ที่เดียวใน `syncAchievements` ครอบคลุมทั้ง 2 ทางที่ปลดล็อกได้
  - `NotificationProvider.unreadCount` นับจากลิสต์ในเครื่อง ไม่ได้ให้ backend ส่งเลขมาแยก
    เข้าหน้า Notification แล้วถือว่าอ่านหมดทันที (`markAllRead`)
- **ร้าน Upgrade Ability ใช้งานได้จริงแล้ว** — การ์ด "Upgrade your Ability" ในหน้า Profile ซื้อได้จริง
  ผ่าน `GET /api/upgrades` + `POST /api/upgrades/:upgradeType/buy` ขาย 5 ตัว: Point Booster, XP Booster,
  Rank Booster, Party Bonus Points, Quest Unlock — ซื้อซ้ำได้สูงสุด 50 ระดับ (Quest Unlock 14 ระดับ
  เพราะมี solo quest แค่ 18 อัน) แต่ละระดับเพิ่มผล 1% (Quest Unlock เพิ่ม 1 เควส) ราคาแพงขึ้นทุกระดับ
  - นิยาม + สูตรทั้งหมดอยู่ที่ **`backend/utils/upgrades.js` ไฟล์เดียว** (แนวเดียวกับ `progression.js`)
  - ⚠️ **XP Booster กับ Rank Booster ตั้งใจแยกกัน ไม่ใช่บั๊ก** — XP Booster คูณ `user.xp` (คิด Level)
    ส่วน Rank Booster คูณค่าที่เขียนลง `QuestHistory.xpEarned` (ผลรวมใน season คิด Rank แยกต่างหาก
    ดู `utils/profilePayload.js`) ซื้อ XP Booster ไม่ทำให้ Rank ขยับเร็วขึ้นด้วย ต้องซื้อ Rank Booster แยก
  - หักแต้มแบบ atomic ด้วย `findOneAndUpdate({points: {$gte: cost}}, {$inc: {points: -cost}})`
    (compare-and-swap แบบเดียวกับ latch ที่ `routes/party.js` ใช้กันคะแนนซ้ำ) กันทั้งแต้มติดลบและกดซื้อซ้อนกัน
  - `GET /api/quests` คูณ `scorePoints`/`xpReward` ที่โชว์บนการ์ดด้วย upgrade ของผู้เล่นแล้ว และ
    จำกัดจำนวน **solo** quest ที่เห็นตามระดับ Quest Unlock (party quest เห็นครบเสมอ ไม่งั้นสร้างห้องไม่ได้)
  - ทุกจุดที่ให้รางวัล (`routes/quests.js`, `routes/party.js` fan-out) คำนวณ bonus ครั้งเดียวแล้วใช้ค่า
    เดียวกันทั้ง `QuestHistory`, ยอดผู้ใช้, response, และข้อความแจ้งเตือน ไม่งั้นตัวเลขจะไม่ตรงกันเอง
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
  - `backend/models/Party.js` (**collection ใหม่**) — `{ questId, leaderId, name, eventDate, location, capacity, status: 'open'|'started'|'completed', startedAt, completedAt }`
    1 quest template สร้างได้หลายห้อง คนละเวลา/สถานที่กัน
  - `backend/models/PartyMember.js` — ผูกกับ `partyId` (เดิมผูกกับ `questId` ตรงๆ) + unique index `(partyId, userId)`
    คนสร้างห้องเป็น leader ทันที; ถ้า leader ออกก่อนอีเวนต์จบ ตำแหน่งจะตกไปคนถัดไปตาม `joinedAt`
  - **⚠️ ด่าน Start กันปั๊มคะแนน** (`backend/utils/partyGate.js`) — เดิมสร้างห้องแล้วกด Complete ได้ทันที
    ไม่ต้องทำอะไรจริงเลย ตอนนี้ต้องผ่าน `open → started → completed` เท่านั้น:
    - **บังคับตั้ง `capacity` อย่างน้อย 2 คนเสมอ** สำหรับห้องใหม่ (เลิกรองรับ "ไม่จำกัดคน") เพราะเงื่อนไข
      "สมาชิกครบ" นิยามไม่ได้ถ้าไม่จำกัด — ห้องเก่าที่ยังมี `capacity: 0` ค้างใน DB ใช้ `MIN_PARTY_MEMBERS = 2`
      แทนผ่าน `requiredMembers(party)`
    - `POST /api/party/start` (หัวหน้าเท่านั้น) — กดได้ต่อเมื่อ **ถึง `eventDate`** แล้ว **และสมาชิกครบ**
      (`canStart()`) เช็คก่อน latch เสมอ แล้วค่อย `findOneAndUpdate` เปลี่ยน `open→started` + ตั้ง `startedAt`
    - `POST /api/party/complete` เปลี่ยน latch จาก `status:'open'` เป็น **`status:'started'`** และเพิ่มเงื่อนไข
      **ต้องผ่านมาแล้วอย่างน้อย 15 นาทีนับจาก `startedAt`** (`canComplete()`, `START_TO_COMPLETE_MS`)
      ก่อน latch เช่นกัน — กันกด Start แล้วกด Complete รัวๆ ต่อกันทันที
    - `toPartyPayload()` ส่ง `memberCount`, `requiredMembers`, `canStart`, `startBlockedReason`,
      `canComplete`, `completeBlockedReason` มาด้วย ให้แอพโชว์/ซ่อนปุ่มได้เลยไม่ต้อง mirror สูตรเอง
      (ฝั่งแอพยัง mirror คร่าวๆ ไว้ที่ `PartyModel.isReadyToStartAt`/`completeCountdownAt` เพื่อนับถอยหลัง
      แบบ live ด้วย `Timer.periodic` โดยไม่ต้องรอ backend ตอบ — **backend เป็นคนตัดสินจริงเสมอ** ทุก request
      ยังเช็คซ้ำที่ server หมด ไม่เชื่อค่าที่แอพคำนวณเอง)
  - `backend/routes/party.js` (mount ที่ `/api/party`)
    - `GET /api/party` → ห้องที่ฉันอยู่ตอนนี้ (`{ party: null }` ถ้ายังไม่ได้เข้าห้องไหน)
    - `GET /api/party/rooms` → ลิสต์ห้องที่ยังเปิดรับสมาชิกอยู่ (`status: 'open'`) ให้เลือกเข้าร่วม — ห้องที่
      `started` แล้วหายจากลิสต์นี้อัตโนมัติ (เต็มคนแล้วเข้าร่วมไม่ได้อยู่ดี)
    - `POST /api/party` → สร้างห้องใหม่จาก party quest — เช็ค `quest.minLevelToHost` ด้วย (ใช้จริงแล้ว ไม่ใช่ dead field)
    - `POST /api/party/start` → ดูหัวข้อด่านกันปั๊มคะแนนด้านบน
    - `POST /api/party/join/:partyId` (บล็อกห้องที่ `started`/`completed` แล้ว), `POST /api/party/leave`
      (leave ตอนห้อง completed = แค่ dismiss)
    - **`POST /api/party/complete`** — **เฉพาะหัวหน้าห้องกดได้** ทุกคนในห้อง (รวมหัวหน้า) ได้ P/XP พร้อมกัน
      ล็อกสถานะเป็น `completed` แบบ atomic (`findOneAndUpdate` เช็ค `status: 'started'` ไปด้วย) กันกดซ้ำได้คะแนนซ้ำ
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
  - **หน้า Party เหลือแค่ "ห้องของฉัน"** (`lib/pages/party/party_page.dart`) มี `Timer.periodic` 1 วินาที
    ทั้งหน้า (แพทเทิร์นเดียวกับตัวนับถอยหลังของหมดอายุใน `fridge_page.dart`) ให้ปุ่ม Start/Complete
    enable เองพอถึงเวลา ไม่ต้องกด pull-to-refresh — 3 สถานะ:
    1. ยังไม่อยู่ห้องไหน → ป้ายว่าง + ปุ่ม "Browse Parties" พาไปแท็บ Explore
    2. อยู่ห้องที่ `status: open` → **หัวหน้าเห็นปุ่ม "Start Event"** (disable + โชว์เหตุผลถ้ายังไม่ถึงเวลานัด
       หรือคนไม่ครบ เช่น "Waiting for members (1/2)") **สมาชิกทั่วไปเห็นป้ายรอ** เหมือนกัน
    3. อยู่ห้องที่ `status: started` → **หัวหน้าเห็นปุ่ม "Complete Event"** (disable พร้อมนับถอยหลัง
       "Available in 08:24" จนกว่าจะครบ 15 นาทีนับจาก `startedAt`) สมาชิกเห็นป้าย "Event in progress..."
       ทั้งหมดกด "Leave Party" ได้เสมอทุกสถานะ; ห้อง `status: completed` → แบนเนอร์สรุปรางวัลค้างไว้ให้เห็นก่อน
       แล้วกด "Back to Parties" (= dismiss ผ่าน `POST /party/leave` ตัวเดิม) ถึงจะไปสร้าง/เข้าร่วมห้องใหม่ได้
    - หน้าสร้างห้อง (`create_party_page.dart`) ตัด option "Unlimited" ออกจาก capacity stepper แล้ว
      ปุ่มลบหยุดที่ 2 เสมอ (ดูหัวข้อด่านกันปั๊มคะแนนด้านบน)
  - ✅ **กดชื่อสมาชิกในหน้า Party เปิดโปรไฟล์ได้จริงแล้ว** ไม่ใช่ SnackBar "coming soon" อีกต่อไป
    ทุกแถวกดได้ (ไม่ใช่แค่แถวหัวหน้าเหมือนก่อนหน้านี้) — แถวของ**ตัวเอง** สลับไปแท็บ Profile ของจริง
    ส่วนแถวของ**คนอื่น**เปิด `lib/pages/profile/player_profile_page.dart` (โปรไฟล์แบบดูอย่างเดียว)
    ผ่าน `GET /api/users/:id` (ผู้เล่นที่ login แล้วดูของกันและกันได้ทุกคน ไม่ต้องอยู่ห้องเดียวกัน)
    - `backend/routes/users.js` คัดฟิลด์แบบ **allow-list** เท่านั้น (`displayName level xp points rank
      avatarContentType avatarUpdatedAt`) ห้ามใช้ `.select('-password')` เพราะยังหลุด
      `email`/`resetOtpHash`/`resetOtpExpires` ได้ — ส่ง `avatarUrl` (สร้างจาก `avatarUrlFor()`) กลับไปด้วย
      เพราะรูปตอนนี้อยู่บน server แล้ว เปิดจากเครื่องไหนก็ได้
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

### ยังเป็น placeholder / mock
✅ **ไม่มีฟีเจอร์ไหนเป็น mock อีกแล้ว** — ทุกหน้าต่อ backend จริงครบหมด (ล่าสุดคือร้าน Upgrade Ability)

**Route ฝั่ง Flutter** (รวมไว้ที่ `lib/routes/app_routes.dart` ไฟล์เดียว — เพิ่มหน้าใหม่มาแก้ที่นี่):
`/splash`, `/login`, `/register`, `/forgot-password`, `/main` (MainShell + bottom nav),
`/settings`, `/change-password`, `/upgrade-account`, `/notifications`, `/fridge`, `/party/create`
> 5 แท็บใน bottom nav ไม่ใช่ route แยก — เป็นหน้าที่สลับกันอยู่ใน `IndexedStack` ของ `MainShell`
> ส่วนหน้าที่ push ทับ (settings / change-password / notifications / fridge / party/create) จะไม่มี bottom nav ให้เห็น
> หน้าโปรไฟล์ของผู้เล่นคนอื่น (`player_profile_page.dart`) รับ `userId` เป็น argument เลยไม่ได้ลงทะเบียนที่นี่
> เปิดผ่าน `MaterialPageRoute` ตรงๆ แทน (แบบเดียวกับ `QuestDetailPage`)

**Backend routes ที่มีแล้ว**
- `backend/routes/auth.js` → mount ที่ `/api/auth`:
  `POST /register`, `POST /login`, `POST /guest`, `GET /me`, `POST /upgrade-guest`, `POST /avatar`,
  `POST /display-name`, `POST /notification-preference`,
  `POST /verify-password`, `POST /change-password`,
  `POST /forgot-password`, `POST /verify-reset-otp`, `POST /reset-password`
- `backend/routes/quests.js` → mount ที่ `/api/quests`: `GET /`, `GET /history?limit=` , `POST /:id/complete` (ต้อง login ทั้งหมด)
  (`/history` ต้องประกาศก่อน route ที่มี `:id` ไม่งั้นคำว่า history จะถูกจับเป็น id)
- `backend/routes/fridgeItems.js` → mount ที่ `/api/fridge-items`: `GET /`, `POST /`, `DELETE /:id` (ต้อง login ทั้งหมด)
- `backend/routes/achievements.js` → mount ที่ `/api/achievements`: `GET /` (ต้อง login)
- `backend/routes/party.js` → mount ที่ `/api/party`: `GET /`, `GET /rooms`, `POST /`, `POST /join/:partyId`,
  `POST /leave`, `POST /complete` (ต้อง login ทั้งหมด)
- `backend/routes/users.js` → mount ที่ `/api/users`: `GET /:id` (โปรไฟล์สาธารณะของผู้เล่นคนอื่น, ต้อง login),
  `GET /:id/avatar` (เสิร์ฟรูปโปรไฟล์ — **ไม่ต้อง login**, ดูหัวข้อ avatar ด้านบน)
- `backend/routes/inventory.js` → mount ที่ `/api/inventory`: `GET /` (แจกไอเทมตั้งต้น Camera/Fridge
  อัตโนมัติถ้ายังไม่มี, ส่งไอเทม Energy ที่ซื้อได้มาด้วยเสมอแม้ยังไม่เคยซื้อ), `POST /:itemType/buy`,
  `POST /:itemType/use` (ดูหัวข้อ "ไอเทม Energy" ด้านบน)
- `backend/routes/notifications.js` → mount ที่ `/api/notifications`: `GET /`, `POST /read`
  (สร้างแจ้งเตือนของใกล้หมดอายุแบบ lazy ตอน `GET /` เพราะไม่มี scheduler — ดูหัวข้อ "ระบบแจ้งเตือน" ด้านบน)
- `backend/routes/upgrades.js` → mount ที่ `/api/upgrades`: `GET /`, `POST /:upgradeType/buy`
  (ดูหัวข้อ "ร้าน Upgrade Ability" ด้านบน)
- สคริปต์: `npm run seed:quests` (`backend/scripts/seedQuests.js`)
- `backend/routes/admin.js` → mount ที่ `/api/admin`: **dev/QA เท่านั้น** ทุก route ต้องผ่าน
  `authMiddleware` + `adminMiddleware` (`backend/middleware/admin.js`) คู่กันเสมอ — เข้าได้เฉพาะบัญชีจริง
  (ไม่ใช่ guest) ที่ `email` อยู่ใน env var `ADMIN_EMAILS` (คั่นด้วย `,` หลายอีเมลได้) ไม่ตั้งค่า =
  ปิดทั้งหมดโดย default (403 เสมอ) **ต้องตั้ง `ADMIN_EMAILS` เองทั้งในเครื่องและบน Render ถึงจะใช้ได้จริง**
  ดู `.env.example` — `GET /auth/me` คำนวณ `isAdmin` ด้วย logic เดียวกันส่งกลับมาด้วย ใช้แค่โชว์/ซ่อนเมนู
  "Admin Tools" ในหน้า Settings ฝั่งแอพ (ไม่ใช่ตัวเช็คสิทธิ์จริง — ทุก request ยังถูกเช็คซ้ำที่ backend เสมอ)
  - ทำงานกับบัญชีของแอดมินเอง (`req.userId`) เสมอ ไม่มี user-picker — ครอบคลุมทุกระบบ: User (set
    points/xp/level ตรงๆ, เปิด/ปิดบัฟ Energy, reset บัญชีทั้งบัญชี), Quest (force-complete ข้ามทุก
    เงื่อนไข, reset ประวัติวันนี้/ทั้งหมด), Party (list ทุกห้อง + force-start/force-complete ข้ามเช็ค
    leader/เวลานัด/15 นาทีหลัง start — force-complete รับได้ทั้งห้อง `open` และ `started`),
    Achievement (unlock/reset), Inventory (grant ไอเทมไหนก็ได้ข้าม cost/reset), Upgrade (set level
    ตรงๆ ข้าม cost), Season (list + บังคับหมดอายุแล้วเรียก `ensureActiveSeason()` จริงต่อทันที),
    Notification (ยิงแจ้งเตือนทดสอบ 3 แบบ), Fridge (เพิ่มของทดสอบกำหนด expiry เองได้)
  - ฝั่งแอพ: `lib/pages/admin/admin_page.dart` (ธีม Material เรียบๆ ไม่ใช้ธีมกระจกมืดของเกมจริง — ตั้งใจ
    ให้ดูต่างจากเกมชัดๆ) เรียกผ่าน `lib/services/admin_service.dart` + `AdminProvider`
    (`lib/providers/admin_provider.dart`) — หลังทุก action ที่สำเร็จ หน้าเพจเรียก provider เดิมของระบบ
    นั้น refresh ต่อเอง (`AuthProvider.refreshProfile()`, `QuestProvider.loadQuests()` ฯลฯ) ไม่เก็บ state
    ซ้ำเอง

`GET /api/auth/me` คืน 3 ก้อน: `user` (+ level/xp/points/rank), `progress` (ความคืบหน้า level/rank),
`stats` (questCompleted / questTotal / co2SavedKg / partiesJoined — คำนวณจริงจาก `QuestHistory` + `Quest`)

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
- ✅ **ย่อขนาดไฟล์รูปแล้ว** (เอาไฟล์ที่ย่อแล้วทับชื่อเดิม ไม่ได้แก้โค้ด/pubspec.yaml เลย) — ย่อตามจุดที่
  รูปนั้นแสดงจริงจริงๆ ไม่ได้ย่อเป็น 216×216 ทุกไฟล์แบบเดียวกันหมด เพราะบางไฟล์ (พื้นหลัง/ปกเควส) ใช้ใหญ่กว่านั้นมาก:
  - `camera.png` / `fridge.png` (Inventory) และ `trophy.png` / `fridge_expired.png` (แจ้งเตือน) — โชว์จริง
    แค่ 72×72 logical px เท่านั้น → ย่อเหลือ **216×216** (3x ของ 72 พอสำหรับจอความหนาแน่นสูงสุด)
    ไฟล์ละ ~2MB เหลือแค่ **~25-43KB** (ลดลง ~98%)
  - รูปปกเควส `lib/utils/assets/questimg/*.png` (checkfridge/finishyourmeal/useleftoveringredients) —
    ⚠️ **ไม่ได้ย่อเหลือ 216 เหมือนกลุ่มบน** เพราะใช้ 2 ที่: thumbnail 64×64 ในลิสต์เควส **และ**
    แบนเนอร์เต็มความกว้างจอสูง 260dp ในหน้ารายละเอียดเควส (`quest_detail_page.dart` `_CoverImage`)
    ย่อ 216 จะเบลอมากตอนโชว์เป็นแบนเนอร์ — ย่อเป็น **900×900** แทน (พอสำหรับ cover แต่ลดขนาดไฟล์ลงได้เกินครึ่ง)
  - `background.png` — **ไม่ได้ย่อขนาดพิกเซล** (941×1672 เหมาะสมกับพื้นหลังเต็มจอ BoxFit.cover อยู่แล้ว
    ที่ใช้กันหลายหน้า เช่น Profile/Settings/Party) แค่บีบอัด PNG ใหม่ให้เบาลงเล็กน้อยเท่านั้น
  - ถ้าจะเพิ่มรูปใหม่ในกลุ่ม 72×72 (ไอเทม/แจ้งเตือน) ในอนาคต ควรย่อเหลือ ~216×216 ตั้งแต่ต้นเช่นกัน
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

## 7. งานถัดไปที่แนะนำ

ทุกฟีเจอร์หลักต่อ backend จริงครบแล้ว ไม่มี mock เหลืออยู่ในแอพ งานที่เหลือเป็นงานเสริม/ปรับแต่ง เช่น:
- ทำ upload รูปขึ้น server/cloud storage แทนการเก็บ path ในเครื่อง (รูปโปรไฟล์ + รูปของในตู้เย็น
  เก็บถาวรไม่หายแล้วผ่าน `AppPhotoStorage` แต่ยังเห็นได้แค่บนเครื่องที่ตั้งค่าไว้ ข้ามเครื่องจะไม่เห็น)
- ปรับสมดุลราคา/ผลของ upgrade ถ้าเทสแล้วรู้สึกไม่ลงตัว (แก้ที่ `backend/utils/upgrades.js` ไฟล์เดียว)

## 8. สิ่งที่ฉันคิดออกและต้องการ
1.✅ ระบบไอเทม — เพิ่มไอเทม Energy 4 อย่างที่ซื้อได้ด้วย Points (หน้า Profile) และใช้ได้จริง (ปุ่ม Use ที่หน้า
  Inventory) แล้ว: Red/Blue/Green Energy คูณ Points/XP/Party Points 2 เท่านาน 30 นาที, Super Energy
  รีเซ็ทเควสที่ทำวันนี้ให้ทำใหม่ได้ (ดูหัวข้อ 5 "ไอเทม Energy") — เดิมเคยลองทำเป็นไอเทมสะสม/badge ผูกกับ
  เหรียญ Achievement ไปรอบนึงแต่ถูกยกเลิกแล้วเปลี่ยนมาทำแบบนี้แทนตามที่ขอ
2.✅ ระบบตั้งค่า — เพิ่ม "Edit Display Name", toggle เปิด/ปิดการแจ้งเตือน, และ About แล้ว (ดูหัวข้อ 5)
3.✅ ระบบเสียง — เล่นเพลงพื้นหลัง + เสียงกดปุ่มจริงแล้ว (ผู้ใช้อัปโหลดไฟล์เสียงเข้ามาแล้ว) ปรับระดับเสียง
  แยกกันได้ในหน้า Settings (Background Music / Sound Effects คนละสไลเดอร์ เหมือนเกม) — ดูหัวข้อ 5
4.✅ เอฟเฟคใบไม้ลอยตกในพื้นหลัง — เพิ่มแล้วทุกหน้าที่มีพื้นหลังธีม (`lib/widgets/falling_leaves_overlay.dart`)
  ยังไม่ได้ทำเอฟเฟคอย่างอื่นเพิ่มเติม (เสียงกดปุ่ม, การเคลื่อนไหวจุดอื่นๆ) ถ้าอยากได้เพิ่มบอกได้เลย
5.✅ **ทำครบทั้ง 8 Phase แล้ว (Phase 0-7) — แผนเต็มที่ `C:\Users\parto\.claude\plans\wild-knitting-nova.md`** เดิม: "ฉันอยากแก้หน้า
  Party เปลี่ยนเป็น Community โดยจะมีหน้าแยกคือ Friend เพื่อให้คนเพิ่มเพื่อนค้นหาเพื่อนได้ , Party เพื่อ
  แสดงว่าตัวเองอยู่ Party อะไรถ้ายังไม่มีก็จะแสดง Party ที่ว่างและให้คนเข้าร่วมได้อยู่ , Chat จะเป็นหน้า
  ที่คนสามารถพูดคุยได้ เป็น Chatโลก Chatปาร์ตี Chatเพื่อน" — ตัดสินใจแล้ว: Chat = real-time ผ่าน
  WebSocket (ไม่ใช่ poll แม้ backend อยู่ Render free tier ที่ sleep ~15 นาที), 3 ส่วนย่อยเป็น
  **`TabBar`** (⚠️ ตัวแรกในโปรเจคนี้ ไม่เคยมีมาก่อน), ค้นหาเพื่อนด้วย `displayName` เดิม (ไม่เพิ่ม
  username ใหม่) แบ่งทำ 8 Phase (0-7) — **Phase 0 (แยก verifyToken.js) + Phase 1 (ย้าย Party มาเป็น
  แท็บย่อยใน Community + เปลี่ยนชื่อ bottom nav) เสร็จแล้ว**:
  - `lib/pages/party/party_page.dart` → ย้ายเป็น `lib/pages/community/party_tab.dart` (คลาส `PartyPage`
    → `PartyTab`) ตัด `Scaffold`/พื้นหลัง/`_TopBar` ("PARTY" title + ปุ่มย้อนกลับ Home) ออก — logic/UI
    ภายในเหมือนเดิมทุกอย่าง (`_PartyView`/`_CompletedView`/`_NoPartyState`/`_GateButton` ฯลฯ)
  - `lib/pages/community/community_page.dart` (ใหม่) — `CommunityPage` มี `TabController` 3 แท็บ
    (Friend/Party/Chat) พื้นหลังธีม (รูป Profile + gradient + ใบไม้ลอยตก) ย้ายมาไว้ที่นี่ที่เดียว
    ให้ทั้ง 3 แท็บย่อยได้ธีมเดียวกันฟรี — `FriendTab`/`ChatTab` ตอนนี้เป็นแค่ placeholder "coming soon"
    รอ Phase 3/5
  - `lib/widgets/bottom_nav_bar.dart` — index 3 เปลี่ยนจาก `Icons.groups_rounded`/'Party' เป็น
    `Icons.diversity_3_rounded`/'Community' (ไม่ใช้ไอคอนเดียวกับแท็บย่อย Party ข้างในกันดูซ้ำ)
  - ✅ **เปลี่ยนธีมหน้า Community เป็นพื้นสว่างแบบ Explore/Inventory แล้ว** (`Colors.grey.shade50`) —
    เดิมใช้ธีมเข้ม (รูป Profile + gradient + ใบไม้ลอยตก) มาก่อน ตัดออกทั้งหมดจาก `community_page.dart`
    เพราะเปลี่ยนพื้นหลังอย่างเดียวจะทำให้การ์ด/ตัวหนังสือสีขาวในแท็บ Party อ่านไม่ออก เลยรีสไตล์
    `party_tab.dart` ทั้งไฟล์ไปด้วย (การ์ดกระจกดำ → การ์ดขาวมีเงา แบบ `InventoryCard`/`QuestCard`,
    ตัวหนังสือ white/white70/white60 → black87/grey.shade600/grey.shade700, reward chip
    amberAccent/greenAccent/lightBlueAccent → amber.shade800/green.shade700/blue.shade700 เพราะสี accent
    จางเกินไปตัดกับพื้นขาวไม่พอ) `FriendTab`/`ChatTab` placeholder ก็ปรับสีให้เข้ากันแล้ว
  - ✅ **Phase 2 (Backend ระบบเพื่อน) เสร็จแล้ว** — ยังไม่มีหน้า UI ให้กด (รอ Phase 3):
    - `backend/models/Friendship.js` (ใหม่) — เอกสารเดียวต่อคู่เพื่อน 1 คู่ (ไม่ใช่ log คำขอ)
      `requesterId`/`recipientId`/`pairKey`(unique index — กันขอซ้ำ/ขอสวนกันพร้อมกัน)/
      `status`(`pending`|`accepted`)/`respondedAt` — ปฏิเสธ/ยกเลิก = deleteOne ทิ้งเลย ไม่เก็บ log
      (แนวเดียวกับที่ `/party/leave` ลบ `PartyMember` ทิ้งตรงๆ)
    - `backend/utils/friendKey.js` (ใหม่) — `pairKey(idA, idB)` ใช้ร่วมกันทั้ง `Friendship.pairKey`
      และจะใช้กับ `ChatMessage.channelId` ของแชทเพื่อนใน Phase 4/7 ด้วย (implementation เดียว)
    - `backend/routes/friends.js` (ใหม่ mount ที่ `/api/friends`): `GET /search?q=` (ค้นหาด้วย
      `displayName` แบบ regex ไม่สนตัวพิมพ์ ตัดตัวเองออก escape ตัวอักษรพิเศษของ regex ก่อนเสมอ กัน
      query พัง/ช้าผิดปกติ — แนบสถานะความสัมพันธ์ `none`/`pending_outgoing`/`pending_incoming`/`friends`
      ต่อผลลัพธ์แต่ละคน), `POST /requests` (ส่งคำขอ — ชน unique index (err 11000) เพราะมีคำขอย้อนกลับ
      รออยู่ก่อน → **auto-accept แทน error** กันเคส 2 คนกดขอกันพร้อมกันพอดี), `GET /requests?direction=`,
      `POST /requests/:id/accept` (atomic CAS แบบเดียวกับ `party.js`'s `/start`/`/complete`),
      `POST /requests/:id/reject`/`cancel` (deleteOne), `GET /` (ลิสต์เพื่อน), `DELETE /:friendUserId`
    - เพิ่ม `'friend_request'`/`'friend_accepted'` เข้า enum `type` ของ `backend/models/Notification.js`
      + `notifyFriendRequest`/`notifyFriendAccepted` ใน `backend/utils/notifications.js` (รูปแบบเดียวกับ
      `notifyQuestCompleted` เดิม) เรียกจาก `friends.js` ตอนส่งคำขอ/ตอบรับ (รวม auto-accept)
    - mount ที่ `backend/server.js` แล้ว (`app.use('/api/friends', friendRoutes)`)
    - ⚠️ **ยังไม่ได้ทดสอบผ่าน HTTP จริงแบบ end-to-end** — ตอนลงมือทำ MongoDB Atlas connect ไม่ติดจาก
      เครื่อง dev (ปัญหา IP whitelist ที่เจอมาก่อนแล้วในโปรเจคนี้ ดูหัวข้อ 6) ทำได้แค่ `node --check`
      ทุกไฟล์ + boot server จริงเช็คว่าไม่ crash + ยืนยันว่า `authMiddleware` reject request ไม่มี token
      ถูกต้อง (401) ส่วน logic ที่พึ่ง DB (ค้นหา/ส่งคำขอ/accept ฯลฯ) ตรวจสอบด้วยการอ่านโค้ดทวนซ้ำเทียบกับ
      pattern ที่พิสูจน์แล้วใน `party.js` เท่านั้น — **ควรทดสอบผ่าน Postman/curl จริงอีกทีตอน deploy**
  - ✅ **Phase 3 (Frontend หน้า Friend) เสร็จแล้ว** — เห็นผลจริงในแอพแล้ว:
    - `lib/models/friend_model.dart` (ใหม่) — `FriendModel`, `FriendSearchResultModel` (มี
      `FriendRelationship` enum: none/pendingOutgoing/pendingIncoming/friends), `FriendRequestModel`
    - `lib/services/friend_service.dart` + `lib/providers/friend_provider.dart` (ใหม่) — รูปแบบ HTTP/
      state เดียวกับ `party_service.dart`/`party_provider.dart` เป๊ะๆ
    - `lib/pages/community/friend_tab.dart` แทนที่ placeholder เดิม — ช่องค้นหา (debounce 400ms กัน
      ยิง API รัวทุกตัวอักษร) สลับ 2 โหมดตามว่ามีคำค้นหาหรือไม่: **โหมดค้นหา** โชว์ผลลัพธ์ + ปุ่ม
      Add/Pending/Friends ตาม relationship, **โหมดปกติ** โชว์คำขอเข้า (Accept/Reject) → คำขอออก
      (Cancel) → ลิสต์เพื่อน (ลบเพื่อนผ่าน `LiquidGlassDialog` confirm) กดแถวไหนก็เปิด
      `PlayerProfilePage` ได้เหมือนแถวสมาชิกปาร์ตี้
    - เพิ่ม `FriendProvider` ใน `lib/main.dart`'s `MultiProvider` แล้ว
    - ⚠️ **ยังไม่ได้ทดสอบ end-to-end จริง** เหตุผลเดียวกับ Phase 2 (MongoDB Atlas connect จากเครื่อง dev
      ไม่ติด + backend/friends.js ยังไม่ได้ deploy ขึ้น Render) ตรวจสอบได้แค่ `flutter analyze` +
      `flutter build apk --debug` ผ่าน — **ต้องทดสอบจริงอีกทีหลัง deploy backend ขึ้น Render แล้ว**
  - ✅ **Phase 4 (Backend WebSocket + World Chat) เสร็จแล้ว**:
    - `backend/models/ChatMessage.js` (ใหม่) — คอลเลกชันเดียวแยกด้วย `channelType`
      (`world`|`party`|`friend`) เหมือน `Notification.js` แยกด้วย `type` — ส่งข้อความทำได้ทาง
      socket เท่านั้น (`chat:send`) REST มีไว้แค่ดึงประวัติ (ทางเขียนทางเดียว ไม่ต้องกังวล sync)
    - `backend/server.js` refactor — เปลี่ยนจาก `app.listen(...)` เป็น `http.createServer(app)` +
      แนบ `socket.io` (`new Server(server, {cors:{origin:'*'}})`) เข้าไป แล้ว `initSocket(io)`
    - `backend/sockets/index.js` (ใหม่) — auth ตอน handshake ผ่าน `verifyToken()` (Phase 0) ทาง
      `socket.handshake.auth.token`, เก็บ `Map<userId, Set<socketId>>` ใน memory (`getSocketsForUser`
      export ไว้ให้ Phase 6 ใช้) — ⚠️ ใช้ได้เพราะ Render free tier รันอินสแตนซ์เดียว, ทุก socket
      join ห้อง `'world'` อัตโนมัติ, `chat:send` รองรับแค่ `channelType: 'world'` ใน Phase นี้
    - `backend/routes/chat.js` (ใหม่ mount ที่ `/api/chat`) — `GET /world/messages?before=&limit=`
    - **⚠️ เวอร์ชัน `socket.io` สำคัญมาก**: README ของ package `socket_io_client` (Dart) ระบุตาราง
      compatibility เอาไว้ชัดเจน — client `v3.*` (ที่ติดตั้งฝั่ง Flutter) ต้องใช้ server **`v4.7.*~v4.*`**
      เท่านั้น (ไม่ใช่ `v4.6.*` ตามที่ pub.dev's หน้าเว็บสรุปไว้ผิด ตอนแรกติดตั้ง `4.6.2` ไปตามหน้าเว็บ
      ก่อนเจอ README จริงในแพ็กเกจแล้วแก้เป็น `4.8.3` — ต้องอ่าน README ที่ติดมากับตัวแพ็กเกจจริง
      อย่าเชื่อสรุปจากหน้าเว็บอย่างเดียว) ปัจจุบัน backend ใช้ `socket.io@4.8.3` (exact pin ไม่ใช่ `^`)
      ซึ่งบังเอิญแก้ CVE เรื่อง `ws`/`engine.io` (DoS) ไปด้วยในตัว (`npm audit` ลดจาก 8 เหลือ 4 ช่อง
      ที่เหลือเป็นของ `nodemailer`/`qs`/`express` เดิมที่ไม่เกี่ยวกับ socket.io เลย)
    - ✅ **ทดสอบจริงแล้วบางส่วน** (ต่างจาก Phase 2-3 ที่ทดสอบ HTTP จริงไม่ได้เลย): boot server local
      แล้วต่อด้วย `socket.io-client` (npm, ใช้ทดสอบเฉยๆ ไม่ได้ติดตั้งจริงในโปรเจค) ยืนยันว่า WebSocket
      handshake + JWT auth ผ่านจริง, `chat:send` validate แล้วพยายามเขียน DB จริง (fail ตาม
      คาดเพราะ MongoDB Atlas connect จากเครื่อง dev ไม่ติด — error ถูก catch ส่ง ack กลับมาถูกต้อง
      ไม่ทำ server crash) — **ยังไม่เคยทดสอบกับ Dart client จริงและยังไม่เคยเห็นข้อความ persist ลง DB
      จริงเพราะ Atlas connect ไม่ติด** ต้องทดสอบอีกทีหลัง deploy ขึ้น Render
  - ✅ **Phase 5 (Frontend โครง Chat + World Chat) เสร็จแล้ว** — เห็นผลจริงในแอพแล้ว (แท็บ Chat ไม่ใช่
    placeholder แล้ว):
    - เพิ่ม `socket_io_client: 3.1.6` ใน `pubspec.yaml` (ตรงกับเวอร์ชัน server ที่ปรับแล้วด้านบน)
    - `lib/models/chat_message_model.dart`, `lib/services/chat_service.dart` (REST ดึงประวัติ),
      `lib/services/chat_socket_service.dart` (ห่อ `IO.Socket` — ใช้ `enableForceNew()` ตอน connect
      กัน package cache Manager เก่าข้ามบัญชี, ใช้ `dispose()` ไม่ใช่ `disconnect()`/`close()` ตามที่
      README เตือนเรื่อง memory leak บน iOS), `lib/providers/chat_provider.dart` (enum
      `ChatConnectionStatus`, เก็บข้อความเป็น map คีย์ด้วย message id กันซ้ำตอน reconnect)
    - `lib/pages/community/chat_tab.dart` แทนที่ placeholder — เปิดใช้ได้แค่ chip "World" (Party/
      Friend chip โชว์ไว้แต่ disabled รอ Phase 6/7), banner "Connecting.../Reconnecting..." แบบไม่
      บล็อก UI ตอนเชื่อมต่อ, เชื่อมต่อ socket แบบ lazy ตอนเปิดแท็บ Chat ครั้งแรกเท่านั้น (ไม่ใช่ตอน
      `main_shell.dart` เปิดแอพ)
    - เพิ่มเรียก `context.read<ChatProvider>().disconnect()` ใน `settings_page.dart`'s
      `_confirmLogout` **ก่อน** `authProvider.logout()` เสมอ กัน session ใหม่ (login คนละบัญชี)
      แอบได้รับ event แชทของบัญชีเก่าที่ยังต่อ socket ค้างอยู่
    - เพิ่ม `ChatProvider` ใน `lib/main.dart`'s `MultiProvider` แล้ว
  - ✅ **Phase 6 (Chat ปาร์ตี้) + Phase 7 (Chat เพื่อน/DM) เสร็จแล้ว** — ครบทุก Phase ของแผนนี้:
    - `backend/sockets/index.js` — ตอน socket connect เช็ค `PartyMember` ของ `socket.userId` ทันที
      ถ้าอยู่ปาร์ตี้อยู่แล้ว join ห้อง `party:<id>` ให้เลย (รองรับ reconnect หลัง backend sleep)
      `chat:send` เพิ่ม 2 branch: `party` (หา partyId จาก membership จริงเสมอ ไม่เชื่อ client),
      `friend` (เช็ค `Friendship` accepted จริงก่อนด้วย `pairKey()` แล้วส่งตรงไปที่ socket ของทั้ง
      สองฝ่ายทุก session/อุปกรณ์ที่เปิดอยู่ — ไม่มี "ห้อง" ตายตัวสำหรับ DM)
    - เพิ่ม `syncPartyRoomForUser(userId, partyId, action)` ใน `sockets/index.js` (export ใหม่) —
      `backend/routes/party.js` เรียกใช้ตอน `POST /` (create), `POST /join/:partyId`, `POST /leave`
      ให้ session ที่เปิดค้างอยู่ join/leave ห้องแชทปาร์ตี้แบบสดทันที ไม่ต้องรอ reconnect ใหม่
      (⚠️ ตัดขอบเขตจากแผนเดิมเล็กน้อย: ไม่ hook เข้า `/start`/`/complete` เพราะ 2 route นั้นไม่ได้
      เปลี่ยน `PartyMember` — ไม่มี room membership ให้ sync)
    - `backend/routes/chat.js` เพิ่ม `GET /party/messages` (หา partyId จาก membership เอง) และ
      `GET /friend/:friendUserId/messages` (เช็ค Friendship accepted ก่อนเสมอ)
    - Frontend: `chat_service.dart` เพิ่ม `fetchPartyHistory()`/`fetchFriendHistory(friendUserId)`,
      `chat_provider.dart` เก็บข้อความแยกคีย์ต่อ channel (`'world'`/`'party'`/`'friend:<userId>'` —
      แชทเพื่อนต้องแยกคีย์ต่อคนคุย เพราะคุยได้หลายคน) เพิ่ม `sendPartyMessage`/`sendFriendMessage`/
      `loadPartyHistory`/`loadFriendHistory`
    - `lib/pages/community/chat_tab.dart` — เปิดใช้ครบทั้ง 3 chip แล้ว: Party enable เฉพาะตอน
      `PartyProvider.hasParty`, Friend enable เฉพาะตอนมีเพื่อนอย่างน้อย 1 คน (กดแล้วเปิด bottom
      sheet เลือกว่าจะคุยกับเพื่อนคนไหน) — ออกจากปาร์ตี้ระหว่างอยู่แท็บ Party chat จะเด้งกลับ World
      เองอัตโนมัติ
    - ✅ ทดสอบ boot server + WebSocket handshake ผ่าน socket client จริงอีกรอบ ยืนยันว่า `chat:send`
      channelType `party` ทำงานตามลอจิก (query DB แล้ว fail อย่างสุภาพเพราะ Atlas connect ไม่ติด
      เหมือนทุก Phase ก่อนหน้า ไม่ crash) — **ยังไม่เคยทดสอบกับ Dart client จริงและยังไม่เคยเห็น
      ข้อความ persist ลง DB จริงเลยทั้งโปรเจค Chat** ต้องทดสอบเต็มรูปแบบอีกทีหลัง deploy ขึ้น Render
