# EcoQuest — ค่า kgCO2e ของแต่ละเควส (ฉบับแก้รอบที่ 2)

เอกสารนี้แทนค่าประมาณคร่าวๆ เดิมใน `backend/scripts/seedQuests.js` ด้วยตัวเลขที่มีแหล่งอ้างอิง
**รอบที่ 2 แก้ตามรีวิวรอบที่ 1 ครบทั้ง 10 ข้อ** (รีวิวต้นฉบับเก็บไว้ครบในภาคผนวกท้ายไฟล์)

**แก้โค้ดแล้ว (ทางเต็ม)** — ใส่ค่าและโครงสร้างข้อมูลใหม่ตามหัวข้อ 6–7 ลงโค้ดจริงแล้ว รายละเอียดอยู่ท้ายหัวข้อ 7

---

## สรุปการเปลี่ยนแปลงจากรอบที่ 1

| # | ประเด็นในรีวิว | ทำอะไรในรอบนี้ |
|---|---|---|
| 1 | Food waste factor 2.5 เป็นค่าโลก | เปลี่ยนเป็น **2.22 kgCO2e/kg** ของญี่ปุ่น (1,046 หมื่นตัน CO2 ÷ 472 หมื่นตัน food loss, FY2022) — ⚠️ แก้ชื่อแหล่งนิดหนึ่ง: ตัวเลข CO2 มาจาก **สำนักงานผู้บริโภค (CAA)** ส่วนปริมาณ food loss มาจากกระทรวงสิ่งแวดล้อม (MOE) |
| 2 | Finish Your Meal "64 g/มื้อ" เกินกว่าที่ source รองรับ | **รีวิวถูก** — เปิดงานวิจัยต้นฉบับแล้ว ตัวเลขเป็นเศษอาหารรวม "ต่อครัวเรือน" จากการชั่งวันเดียว ไม่ใช่ต่อมื้อ ทิ้งข้อมูลฟิลิปปินส์ไปเลย ใช้ข้อมูลญี่ปุ่นแยกประเภท "กินเหลือ (食べ残し)" แทน → **0.05** |
| 3 | Check Food = 0.05 มาจาก 30% ที่ตั้งเอง | เอาออก → **ไม่นับ CO2 (null)** |
| 4 | Food Saver ใช้ข้อมูล UK | เปลี่ยนเป็นข้อมูลครัวเรือนญี่ปุ่น → **0.12 / 0.35 / 0.81** + แนะนำให้นับทีละวันที่ยืนยันแล้ว ไม่ใช่นับล่วงหน้าทั้งก้อน |
| 5 | ขวดน้ำ 0.08 ไม่ควรเป็น High | ลดเป็น 🟡 และระบุว่าเป็นค่า "gross" (ยังไม่หักผลกระทบของขวดใช้ซ้ำเอง) |
| 6 | Reuse a Plastic Bottle 1/3 ตั้งเอง | เอาออก → **null** |
| 7 | ถุงผ้า ต้องคิด footprint ถุงผ้าด้วย | ลดเป็น 🟡 ต่ำ-กลาง + **แก้การปัดเศษ**: รอบที่แล้วปัด 0.011 ขึ้นเป็น 0.02 (เกินจริงเกือบเท่าตัว) ที่ถูกคือ **0.01** |
| 8 | Refill: ลดพลาสติกมีหลักฐาน แต่ CO2 ยังไม่ exact | เปลี่ยนแหล่งเป็น **กระทรวงสิ่งแวดล้อมญี่ปุ่น (70–80%)** แทน Zacros (80–90%) และติดป้ายว่าเป็น "ค่าประมาณ" ไม่ใช่ exact |
| 9 | Recycling ไม่ควรใช้ 0.3 เป็นค่ากลาง | Sort Waste + Recycling Drive → **null** ใช้หน่วยอื่นแทน |
| 10 | ค่าไฟฮอกไกโด 0.4 ต่ำไป | ยืนยันจากเว็บ Hokkaido Electric แล้ว: FY2025 = **0.536 (unadjusted) / 0.522 (basic & adjusted)** — ⚠️ เว็บระบุว่า **เป็นค่าชั่วคราว (暫定値)** → ไฟ/ปลั๊ก = **0.06** |
| 11 | Tree Planting "6 kg ปีแรก" source ไม่รองรับ | **รีวิวถูก และเป็นความผิดของผมเอง** — เลข 5.9 kg มาจากสรุปผลค้นหา ไม่ได้อยู่ในหน้า One Tree Planted (หน้านั้นบอก ~10 kg/ต้น/ปี เฉลี่ย 20 ปีแรก) → **null** |
| 12 | Community Cleanup 2.0 ไม่มีหลักฐาน | → **null** ใช้หน่วย "kg ขยะที่เก็บได้" แทน |
| 13 | Double counting | เพิ่มหัวข้อ 6 + ข้อเสนอ `overlapGroup` |
| 14 | แยก CO2e ออกจาก Environmental Impact | เพิ่มหัวข้อ 7 — **ใช้ฟิลด์ `impact` (low/medium/high) ที่มีอยู่แล้วใน Quest** แทนการเพิ่มฟิลด์ใหม่ซ้ำซ้อน |

**เจอปัญหาเพิ่มเองตอนเช็คโค้ด:** แอพแสดงค่า CO2 เป็นทศนิยม 1 ตำแหน่ง (`toStringAsFixed(1)`) ค่าใหม่ที่เล็กลง
เช่น 0.04 จะโชว์เป็น **"0.0 kg"** ต้องแก้หน้าแสดงผลพร้อมกัน (ดูหัวข้อ 7)

---

## ตารางสรุป (รอบที่ 2)

| เควส | เดิม | รอบ 1 | **รอบ 2** | ความมั่นใจ | กลุ่มนับซ้ำ |
|---|---|---|---|---|---|
| Finish Your Meal | 0.15 | 0.15 | **0.05** | 🟡 | food_waste |
| Check Your Food & Expiration Dates | 0.2 | 0.05 | **null** | 🔴 ไม่นับ | — |
| Use Leftover Ingredients | 0.2 | 0.35 | **0.05** | 🟡 | food_waste |
| Food Saver — 1 Day | 0.2 | 0.6 | **0.12** | 🟡 | food_waste |
| Food Saver — 3 Days | 0.6 | 1.8 | **0.35** | 🟡 (ถ้ายืนยันครบ 3 วัน) | food_waste |
| Food Saver — 7 Days | 1.4 | 4.2 | **0.81** | 🟡 (ถ้ายืนยันครบ 7 วัน) | food_waste |
| Use a Reusable Bottle | 0.08 | 0.08 | **0.08** | 🟡 gross | single_use_plastic |
| Refill Your Water Bottle | 0.08 | 0.08 | **0.08** | 🟡 gross | single_use_plastic |
| Reuse a Plastic Bottle | 0.08 | 0.03 | **null** | 🔴 ไม่นับ | — |
| Bring Your Own Shopping Bag | 0.03 | 0.02 | **0.01** | 🟡 ต่ำ-กลาง | single_use_plastic |
| Buy Refill Products | 0.12 | 0.05 | **0.05** | 🟡 ประมาณการ | (ดูหัวข้อ 6) |
| Use Refillable Laundry Detergent | 0.25 | 0.08 | **0.07** | 🟡 ประมาณการ | — |
| Use Refillable Dish Soap | 0.2 | 0.04 | **0.04** | 🟡 ประมาณการ | — |
| Use Reusable Food Containers | 0.15 | 0.02 | **0.02** | 🟡 ประมาณการ | single_use_plastic |
| Avoid Single-Use Plastic for One Day | 0.3 | 0.13 | **0.12** | 🟡 | single_use_plastic |
| Sort Waste Correctly | 0.1 | 0.08 | **null** | 🔴 ไม่นับ | — |
| Neighborhood Recycling Drive | 1.5 | 1.2 | **null** | 🔴 ไม่นับ | — |
| Turn Off Unused Lights | 0.1 | 0.05 | **0.06** | 🟢 ตัวคูณ / 🟡 สมมติฐานการใช้ | — |
| Unplug Unused Devices | 0.12 | 0.05 | **0.06** | 🟢 ตัวคูณ / 🟡 สมมติฐานการใช้ | — |
| Community Cleanup | 2.0 | 2.0 | **null** | 🔴 ไม่นับ | — |
| Tree Planting Day | 5.0 | 6.0 | **null** | 🔴 ไม่นับ (เป็นการดูดซับในอนาคต) | — |

- 🟢 = ใช้ตัวเลขทางการตรงๆ
- 🟡 = ตัวคูณมีแหล่งอ้างอิง แต่ปริมาณ/พฤติกรรมต้องตั้งสมมติฐานเอง → แสดงผู้ใช้ว่า "ประมาณ"
- 🔴 = ไม่ใส่ค่า CO2 (`null`) ใช้หน่วยวัดที่ตรงกับกิจกรรมแทน (หัวข้อ 7)
- ไม่มีเควสไหนได้ 🟢 ทั้งแถว เพราะทุกเควสต้องสมมติปริมาณเอง แม้แต่เควสที่ตัวคูณแม่นที่สุด (ค่าไฟ)

---

## 1. Food Waste — ใช้ข้อมูลญี่ปุ่นทั้งหมด

**ตัวคูณ:** food loss ทั้งประเทศ FY2022 = **472 หมื่นตัน** (MOE) ก่อ CO2 **1,046 หมื่นตัน**
(CAA) → 10.46 ÷ 4.72 = **2.22 kgCO2e ต่อ kg** (ค่าเฉลี่ยทั้งญี่ปุ่น ไม่ใช่ค่าเฉพาะเอเบ็ตสึ) — CAA
คิดเป็นต่อหัวได้ 83 kgCO2/คน/ปี

**ปริมาณ:** food loss ของครัวเรือน FY2022 = **236 หมื่นตัน** แยกเป็น (MOE):
- กินเหลือ (食べ残し) ~100 หมื่นตัน (43%)
- ทิ้งทั้งชิ้นโดยไม่ได้ใช้ (直接廃棄) ~102 หมื่นตัน (43%)
- ตัด/ปอกทิ้งเกิน (過剰除去) ~33 หมื่นตัน (14%)

หารด้วยประชากร ~1.249 ร้อยล้านคน (ต.ค. 2022) และ 365 วัน:

| เควส | ใช้ประเภทไหน | ต่อคนต่อวัน | × 2.22 | ค่า |
|---|---|---|---|---|
| Finish Your Meal | กินเหลือ — ตรงกับตัวเควส ("กินให้หมดจานวันนี้") | 21.9 g | 0.049 | **0.05** |
| Use Leftover Ingredients | ทิ้งทั้งชิ้น — ตรงกับตัวเควส ("เอาวัตถุดิบใกล้เสียมาทำอาหาร") | 22.4 g | 0.050 | **0.05** |
| Food Saver — 1 Day | food loss ครัวเรือนทั้งหมด | 51.8 g | 0.115 | **0.12** |
| Food Saver — 3 Days | × 3 วัน | 155 g | 0.345 | **0.35** |
| Food Saver — 7 Days | × 7 วัน | 363 g | 0.805 | **0.81** |
| Check Your Food & Expiration Dates | ไม่มีอาหารถูกกิน/ทิ้งจากการกระทำนี้ | — | — | **null** |

**วิธีตีความ:** ค่าเหล่านี้คือ "food loss เฉลี่ยของคนญี่ปุ่นหนึ่งคนที่เลี่ยงได้" ถ้าวันนั้นผู้เล่นไม่มีขยะอาหาร
เลย ไม่ใช่การวัดของจริงที่ผู้เล่นช่วยไว้

⚠️ **Use Leftover Ingredients อาจต่ำกว่าจริง:** วัตถุดิบหนึ่งชิ้นที่ช่วยไว้ได้ (เช่น ผัก 1 หัว) มักหนักกว่า
ค่าเฉลี่ย 22 g/วัน — เลือกใช้ค่าเฉลี่ยประเทศเพราะมีแหล่งรองรับ ดีกว่าตั้งตัวเลข 150 g เองแบบรอบที่ 1

⚠️ **Food Saver 3/7 วัน:** ตอนนี้ผู้เล่นกด Complete ได้ทันทีในวันแรก แต่ได้เครดิตทั้ง 3/7 วันล่วงหน้า
โดยไม่มีอะไรยืนยัน — แนะนำให้นับทีละวันที่ผ่านจริง (0.12 ต่อวัน) ดูหัวข้อ 6

---

## 2. Plastic — เป็นค่าประมาณทั้งหมด

**ตัวคูณ:** ~2 kgCO2e ต่อ kg พลาสติก (ค่ากลางจากงานวิจัย LCA การผลิต PE/PET) — ไม่เปลี่ยนจากรอบที่ 1
แต่ทุกค่าในหมวดนี้เป็น **ค่า gross**: นับเฉพาะพลาสติกใช้ครั้งเดียวที่เลี่ยงได้ ยังไม่หักผลกระทบของของ
ใช้ซ้ำเอง (การผลิต/การล้างขวดน้ำ ถุงผ้า กล่อง) ซึ่งขึ้นกับว่าผู้เล่นใช้ของนั้นซ้ำกี่ครั้ง

| เควส | ที่มาของตัวเลข | ค่า |
|---|---|---|
| Use a Reusable Bottle / Refill Your Water Bottle | ขวด PET 500 ml ~80 g CO2e ต่อใบ — ⚠️ รีวิวถูก: งาน LCA ของ NIH ให้ **เป็นช่วง** ไม่ใช่เลขเดียว (82.8 g มาจากแหล่งอื่นที่อ้างใช้) ใช้เป็นค่าประมาณกลางช่วง | **0.08** |
| Reuse a Plastic Bottle | ขวดถูกผลิตไปแล้ว ประโยชน์จริงวัดไม่ได้ (สัดส่วน 1/3 ของรอบที่ 1 ตั้งขึ้นเอง) | **null** |
| Bring Your Own Shopping Bag | ถุงหูหิ้ว ~5.5 g × 2 = 0.011 | **0.01** |
| Buy Refill Products (ทั่วไป) | ขวด ~30 g × ลดพลาสติก **70–80%** (MOE) = 21–24 g × 2 = 0.042–0.048 | **0.05** |
| Use Refillable Laundry Detergent | ขวด ~45 g × 70–80% = 31.5–36 g × 2 = 0.063–0.072 | **0.07** |
| Use Refillable Dish Soap | ขวด ~25 g × 70–80% = 17.5–20 g × 2 = 0.035–0.040 | **0.04** |
| Use Reusable Food Containers | cling wrap/กล่องใช้แล้วทิ้ง ~8–10 g × 2 | **0.02** |
| Avoid Single-Use Plastic for One Day | ขวด 0.08 + ถุง 0.01 + ภาชนะ 0.02 + หลอด/ช้อนส้อม ~0.01 | **0.12** |

⚠️ น้ำหนักขวดรีฟิล (30/45/25 g) ยังเป็นการประมาณจากขนาดขวดทั่วไป ถ้าอยากให้แม่นขึ้นควรชั่งขวดจริงที่ขาย
ในเอเบ็ตสึ — สิ่งที่มีหลักฐานแข็งแรงคือ **"ลดพลาสติก 70–80%"** ส่วนตัวเลข CO2 เป็นการแปลงต่อจากนั้น

---

## 3. Recycling — ไม่ใส่ค่า CO2

| เควส | ค่า | เหตุผล |
|---|---|---|
| Sort Waste Correctly | **null** | ตัวเลข 250 g/วัน และ 0.3 kgCO2e/kg ในรอบที่ 1 ตั้งขึ้นเองทั้งคู่ และงานวิจัยญี่ปุ่นที่อ้างเปรียบเทียบเฉพาะบางวิธีรีไซเคิลพลาสติก ไม่ได้ครอบคลุมขยะรีไซเคิลทุกชนิด |
| Neighborhood Recycling Drive | **null** | 50 kg/รอบ และ 0.3 ตั้งขึ้นเองทั้งคู่ — หน่วยที่ถูกคือ "kg ที่เก็บได้จริง" ซึ่งแอพยังไม่มีช่องให้กรอก |

---

## 4. Energy — ค่าไฟฮอกไกโดล่าสุด

**ตัวคูณ:** Hokkaido Electric FY2025 = **0.522 kgCO2/kWh** (basic/adjusted — ค่าที่ใช้รายงานตามกฎหมาย)
ส่วนค่า unadjusted = 0.536 — ⚠️ บริษัทระบุว่า **ยังเป็นค่าชั่วคราว (暫定値)** ควรอัปเดตเมื่อประกาศค่าจริง
ทั้งสองค่าปัดแล้วได้ผลเท่ากัน

| เควส | สมมติฐาน | คำนวณ | ค่า |
|---|---|---|---|
| Turn Off Unused Lights | LED 10W × 3 ดวง × 4 ชม. | 0.12 kWh × 0.522 = 0.063 | **0.06** |
| Unplug Unused Devices | standby ~10W × 12 ชม. | 0.12 kWh × 0.522 = 0.063 | **0.06** |

ตัวคูณแม่นที่สุดในเอกสารนี้ แต่ชั่วโมง/จำนวนดวง/วัตต์ยังเป็นสมมติฐาน

---

## 5. Tree Planting & Community Cleanup — ไม่ใส่ค่า CO2

| เควส | ค่า | หน่วยที่ใช้แทน | หมายเหตุ |
|---|---|---|---|
| Tree Planting Day | **null** | จำนวนต้นที่ปลูก | ต้นไม้ดูดซับ CO2 ในอนาคต และขึ้นกับว่าต้นรอดไหม ชนิด และสภาพพื้นที่ — One Tree Planted ให้ค่า **~10 kg/ต้น/ปี เฉลี่ย 20 ปีแรก** ใช้เป็นข้อความเสริมได้ เช่น *"A planted tree may absorb around 10 kg of CO₂ per year over its first 20 years, depending on species and growing conditions."* แต่ไม่รวมเข้า "CO₂ Saved" |
| Community Cleanup | **null** | kg ขยะที่เก็บได้ | ประโยชน์หลักคือลดขยะ/มลพิษ ไม่ใช่ลด GHG |

---

## 6. ป้องกันการนับซ้ำ (Double Counting)

ตอนนี้ `backend/utils/profilePayload.js` บวก `co2SavedKg` ของทุกเควสที่ทำสำเร็จตรงๆ (`$sum`)
เลยนับซ้ำได้ เช่น ทำ Finish Your Meal + Food Saver 1 Day ในวันเดียวกัน = นับขยะอาหารชุดเดียวกัน 2 ครั้ง

**ข้อเสนอ:** เพิ่มฟิลด์ `overlapGroup` ให้เควส แล้วตอนรวมยอด ให้ **บวกกันได้ภายในกลุ่ม แต่ไม่เกินเพดาน
ของกลุ่มต่อวัน** (เพดาน = ค่าสูงสุดที่ทำได้จริงในหนึ่งวัน):

| กลุ่ม | เควส | เพดานต่อวัน | เหตุผลของเพดาน |
|---|---|---|---|
| `food_waste` | Finish Your Meal, Use Leftover Ingredients, Food Saver ×3 | **0.12** | food loss ครัวเรือนต่อคนต่อวันทั้งหมด เลี่ยงได้ไม่เกินนี้ |
| `single_use_plastic` | Reusable Bottle, Refill Water Bottle, Shopping Bag, Food Containers, Avoid Single-Use Plastic | **0.12** | เท่ากับค่าของ "Avoid Single-Use Plastic for One Day" |

ข้อเสนอเพิ่มเติม (แก้ที่ตัวเควส ไม่ต้องใช้กลุ่ม):
- **Use a Reusable Bottle กับ Refill Your Water Bottle เป็นการกระทำเดียวกัน** → แนะนำให้รวมเป็นเควสเดียว
- **Buy Refill Products ทับกับน้ำยาซักผ้า/น้ำยาล้างจาน** → แนะนำให้เปลี่ยนคำเป็น "ผลิตภัณฑ์รีฟิลอื่นๆ
  (แชมพู สบู่เหลว ฯลฯ)" จะได้ไม่ทับกัน
- **Food Saver 3/7 วัน** → นับทีละวัน (0.12 ต่อวันที่ผ่าน) แทนการนับทั้งก้อนตอนกด Complete — ต้องมีระบบ
  ติดตามหลายวัน ถ้ายังไม่พร้อม เพดานกลุ่ม `food_waste` ต่อวันจะจำกัดยอดไว้ที่ 0.12 ให้อยู่แล้ว

---

## 7. ข้อเสนอเปลี่ยนโครงสร้างข้อมูล

แยก "ค่า CO2 ที่ประมาณได้" ออกจาก "ผลกระทบต่อสิ่งแวดล้อม" ตามรีวิว โดย **ใช้ของที่มีอยู่แล้วให้มากที่สุด**:

| ฟิลด์ | สถานะ | ความหมาย |
|---|---|---|
| `impact` (low/medium/high) | **มีอยู่แล้ว** ใน `Quest.js` (ใช้คิดแต้มด้วย) | ใช้เป็น Environmental Impact ได้เลย ไม่ต้องเพิ่ม `environmentalImpact` ซ้ำ |
| `co2eEstimateKg` (number หรือ `null`) | แทน `co2SavedKg` | `null` = ไม่นับ CO2 |
| `impactCategory` (string) | ใหม่ | เช่น "Food Waste Prevented", "Litter Removed", "Tree Planted" |
| `impactMetric` (string) | ใหม่ | หน่วยของการทำ 1 ครั้ง เช่น "days", "bottles", "events" |
| `overlapGroup` (string หรือ `null`) | ใหม่ | สำหรับเพดานต่อวันในหัวข้อ 6 |

**ตัวอย่าง (ตามที่ใส่ในโค้ดจริง):**
```js
{ title: 'Community Cleanup',  impact: 'high',   co2eEstimateKg: null, impactCategory: 'Litter Removed',       impactMetric: 'events' }
{ title: 'Tree Planting Day',  impact: 'high',   co2eEstimateKg: null, impactCategory: 'Trees Planted',        impactMetric: 'events' }
{ title: 'Food Saver — 1 Day', impact: 'medium', co2eEstimateKg: 0.12, impactCategory: 'Food Waste Prevented', impactMetric: 'days', overlapGroup: 'food_waste' }
```

`impactMetric` ใช้หน่วย "ต่อการทำ 1 ครั้ง" (events/days/bottles) แทน "kg ขยะ" หรือ "จำนวนต้น" ที่เสนอไว้
ตอนแรก เพราะแอพยังไม่มีช่องให้กรอกปริมาณจริง — ถ้าวันหลังเพิ่มช่องกรอก (เช่น หัวหน้าห้องกรอก kg ขยะที่
เก็บได้ตอนจบอีเวนต์) ค่อยเปลี่ยนหน่วยเป็น kg

**สิ่งที่แก้ในโค้ดแล้ว:**
1. `backend/models/Quest.js` — เลิกใช้ `co2SavedKg` เพิ่ม `co2eEstimateKg` (null ได้) / `impactCategory` /
   `impactMetric` / `overlapGroup`
2. `backend/scripts/seedQuests.js` — ค่าใหม่ครบ 21 เควสตามตารางสรุป + ลบฟิลด์ `co2SavedKg` เก่าที่ค้างใน DB
   ทิ้งตอน seed (เซิร์ฟเวอร์ seed ให้เองตอน deploy)
3. `backend/utils/profilePayload.js` — ยอด "CO₂ Saved" รวมแบบมีเพดานต่อกลุ่มต่อวัน (`OVERLAP_DAILY_CAP_KG`)
   ตัดวันที่เที่ยงคืนเวลาญี่ปุ่นเหมือนเควสรายวัน — ยอดย้อนหลังของทุกบัญชีคำนวณใหม่ด้วยตัวเลขใหม่อัตโนมัติ
   เพราะอ่านค่าจาก template ของเควสปัจจุบันเสมอ
4. `backend/routes/quests.js`, `backend/routes/party.js` — ส่งฟิลด์ใหม่ออกไปแทน `co2SavedKg`
5. แอพ: โมเดลรับ `co2eEstimateKg` + `lib/utils/co2_format.dart` แสดง **ตัวเลขทศนิยม 2 ตำแหน่ง + หน่วย
   kgCO2e เท่านั้น** ทุกจุด (หน้ารายละเอียดเควส / ชิปรางวัลปาร์ตี้ / ยอดรวมหน้า Profile) เช่น "0.05 kgCO2e"
   - เควสที่เป็น `null` แสดงเป็น "0.00 kgCO2e" — ตรงกับที่ backend นับเป็น 0 ในยอดรวม (ตามที่ผู้ใช้ตัดสินใจ:
     ต้องเป็นตัวเลขหน่วยเดียวกันทั้งหมดเพื่อรวมเป็นยอดในหน้า Profile ได้ ไม่แสดงข้อความ/ระดับผลกระทบแทน)
   - `impactCategory` / `impactMetric` ยังเก็บใน backend เป็นข้อมูลอ้างอิง แต่แอพไม่ได้แสดง

**ยังไม่ได้ทำ (ข้อเสนอเพิ่มเติมในหัวข้อ 6 ที่ต้องแก้ตัวเควส):**
- รวม Use a Reusable Bottle กับ Refill Your Water Bottle เป็นเควสเดียว
- เปลี่ยนคำ Buy Refill Products ไม่ให้ทับน้ำยาซักผ้า/ล้างจาน
- นับ Food Saver 3/7 วันทีละวัน — ตอนนี้หน้าเควสโชว์ ≈ 350 g / ≈ 810 g (รวมทุกวัน) แต่ยอดในโปรไฟล์
  ได้เพิ่มแค่ 120 g ในวันที่กด Complete เพราะติดเพดาน `food_waste` ต่อวัน — ตัวเลขสองที่นี้จะไม่ตรงกันจนกว่า
  จะทำระบบติดตามหลายวัน

---

## แหล่งอ้างอิง

**ใหม่ในรอบที่ 2 (ข้อมูลญี่ปุ่น)**
- [MOE — Japan's Food Loss and Waste FY2022 (EN)](https://www.env.go.jp/en/press/press_02937.html) — 472 หมื่นตัน (ครัวเรือน 236 / ธุรกิจ 236)
- [環境省 — 食品ロスの発生量の推計値（令和4年度）](https://www.env.go.jp/press/press_03332.html) — แยกประเภท 食べ残し/直接廃棄/過剰除去
- [消費者庁 — 食品ロスによる経済損失及び温室効果ガス排出量](https://www.caa.go.jp/notice/entry/047476) — 1,046 หมื่นตัน CO2, 83 kg/คน/ปี
- [北海道電力 — 当社のCO2排出係数](https://www.hepco.co.jp/corporate/environment/global_warming/results_co2.html) — FY2025: 0.536 / 0.522 (暫定値)
- [環境省 プラスチック・スマート — つめかえパックのプラスチック削減](https://plastics-smart.env.go.jp/plasmaction/kobe/1/) — ลดพลาสติก 70–80%

**ยังใช้ต่อจากรอบที่ 1**
- [NIH — Life Cycle Environmental Impact of PET Water Bottles](https://nems.nih.gov/Documents/PETWaterBottlesEnvironmentalImpact.pdf)
- [Drink Local Drink Tap — Carbon Impact of One Single-use Plastic Bottle](https://drinklocaldrinktap.org/2020/03/11/carbon-impact-of-one-single-use-plastic-bottle/)
- [Thunder Said Energy — CO2 from plastics](https://thundersaidenergy.com/downloads/co2-from-plastics-and-petrochemical-facilities/)
- [co2everything.com — Plastic Bag](https://www.co2everything.com/co2e-of/plastic-bag)
- [EnergySage — How Many Watts Does a Light Bulb Use](https://www.energysage.com/electricity/house-watts/how-many-watts-does-a-light-bulb-use/)
- [Wikipedia — Standby power](https://en.wikipedia.org/wiki/Standby_power)
- [One Tree Planted — How Much CO2 Does A Tree Absorb](https://onetreeplanted.org/blogs/stories/how-much-co2-does-tree-absorb) — ~10 kg/ต้น/ปี เฉลี่ย 20 ปีแรก (ใช้เป็นข้อความเสริมเท่านั้น)

**เลิกใช้ในรอบที่ 2**
- FAO 2.5 kgCO2e/kg (ค่าโลก) → ใช้ค่าญี่ปุ่นแทน
- WRAP UK 88 kg/คน/ปี → ใช้ข้อมูลครัวเรือนญี่ปุ่นแทน
- งานวิจัย plate waste ฟิลิปปินส์ (PMC9811705) → หน่วยเป็นต่อครัวเรือน ไม่ใช่ต่อมื้อ
- Zacros (80–90%) → ใช้ตัวเลขกระทรวงสิ่งแวดล้อมญี่ปุ่น (70–80%) แทน
- ScienceDirect ค่า recycling 0.16–0.69 → ไม่ใช้เป็นค่ากลางแล้ว (Sort Waste/Recycling Drive เป็น null)
- Nature 0.43 kgCO2/kWh → ใช้ค่าล่าสุดของ Hokkaido Electric แทน

---

## ขั้นตอนถัดไป

1. ~~ตัดสินใจเรื่องหัวข้อ 7~~ — เลือกทางเต็มแล้ว ทำเสร็จแล้ว
2. ตัดสินใจเรื่องข้อเสนอที่ยังไม่ได้ทำท้ายหัวข้อ 7 (รวมเควสขวดน้ำ / เปลี่ยนคำ Buy Refill Products / นับ
   Food Saver ทีละวัน)
3. ~~แก้หน้าแสดงผลไม่ให้ค่าเล็กๆ โชว์เป็น "0.0 kg"~~ — ทำแล้ว
4. อัปเดตค่าไฟเมื่อ Hokkaido Electric ประกาศค่าจริง FY2025 (ตอนนี้ 0.522 เป็นค่าชั่วคราว)

---

# ภาคผนวก: รีวิวรอบที่ 1 (ต้นฉบับ ไม่ได้แก้ไข)

เก็บไว้อ้างอิงว่ารอบที่ 2 แก้ตามประเด็นไหนบ้าง — ดูตาราง "สรุปการเปลี่ยนแปลงจากรอบที่ 1" ด้านบน

## การแก้ครั้งที่ 1 อ่านและนำไปปรับใช้แก้ไข
จุดที่ “ใช้ต่อได้” แต่ต้องปรับคำอธิบาย
1. Food waste factor 2.5 kgCO2e/kg

ตัวเลข 2.5 ไม่ได้ดูผิดอย่างรุนแรง แต่สำหรับ EcoQuest ที่อยู่ในญี่ปุ่น ผมไม่แนะนำให้ใช้เป็นค่าหลักโดยไม่อธิบายว่าเป็น global average

ข้อมูลญี่ปุ่นของปี FY2022 ระบุ food loss 4.72 ล้านตัน และการปล่อย GHG ที่เกี่ยวข้องประมาณ 10.46 ล้านตัน CO2e ซึ่งคิดเป็นประมาณ 2.22 kgCO2e ต่อ kg food loss โดยรวม

ดังนั้นผมแนะนำ:

เปลี่ยน 2.5 → ประมาณ 2.2 kgCO2e/kg สำหรับ baseline ญี่ปุ่น

และเขียนว่าเป็น Japan-wide average estimate ไม่ใช่ค่าเฉพาะ Ebetsu

จุดที่ต้องแก้ชัดเจน
2. ❌ Finish Your Meal — “64 g/มื้อ”

นี่เป็นจุดที่ผมคิดว่าต้องแก้แน่นอน

งานวิจัยที่คุณอ้างรายงานค่า rice 49.6g, meat/fish/poultry 7.5g และ vegetables 6.7g และพูดถึง household plate waste ต่อวัน ไม่ได้เป็นหลักฐานตรง ๆ ว่า 64g ต่อมื้อ

ในเอกสารคุณเขียน:

~64 g/มื้อ

อันนี้จึงแรงเกินกว่าที่ source รองรับ

ควรเปลี่ยนเป็นประมาณ:

~64–67 g/day per household in the cited Filipino study

และต้องระบุด้วยว่าเป็น Philippine household data ไม่ใช่ Japanese individual data

ดังนั้นค่า 0.15 kg ของ Quest นี้ควรจัดเป็น estimate / medium-low confidence มากกว่า “high”.

3. ❌ Check Your Food & Expiration Dates = 0.05 kg

อันนี้เป็นจุดที่ผมแนะนำให้ เอาออกจาก CO2 calculation ไปเลย

เพราะคุณเขียนชัดเจนเองว่า:

ไม่มีอาหารถูกกินหรือทิ้งจริงจาก action นี้
และ 0.05 มาจาก 0.15 × 0.3

30% ตรงนี้เป็น สมมติฐานที่สร้างขึ้นเอง ไม่ใช่ตัวเลขที่งานวิจัยบอกว่า “การเช็คตู้เย็นลด CO2 ได้ 30%”

ดังนั้นควรเป็น:

CO2 Saved = 0 / Not directly measurable

แต่ Quest นี้ยังมีประโยชน์มากในระบบเกม เพราะเป็น enabling action ที่ช่วยให้ผู้ใช้ทำ Quest อื่นได้ดีขึ้น

4. ❌ Food Saver 1/3/7 Days = 0.6 / 1.8 / 4.2

นี่เป็นอีกจุดที่ควรแก้มากที่สุด

ตอนนี้คุณใช้:

88 kg/person/year → 0.24 kg/day

จากข้อมูล UK WRAP

ตัวเลข 88 kg/person/year จาก WRAP มีอยู่จริง แต่ปัญหาคือ EcoQuest อยู่ญี่ปุ่น

ญี่ปุ่นปี 2022 มี household food loss ประมาณ 2.36 million tonnes ซึ่งต่ำกว่าการเอา UK 88kg/person/year มาใช้โดยตรงมาก

ดังนั้นผมแนะนำให้เปลี่ยน methodology เป็น:

Japan household food-loss baseline → kg/person/day → CO2 factor

แทนการใช้ 88kg ของ UK

และต้องระวังอีกอย่าง:

Food Saver 7 Days ไม่ควรแปลว่า “ผู้ใช้ป้องกัน food waste ได้ทั้งหมด 7 วัน” เว้นแต่แอปของคุณมีระบบวัดอาหารที่ผู้ใช้ช่วยไว้จริง

Plastic — หลายตัว “คำนวณได้ แต่ยังไม่ควรบอกว่าแม่น”
5. Use a Reusable Bottle / Refill Your Water Bottle

ค่า 0.08 kg มีเหตุผลในระดับ approximation แต่ source ของ NIH ให้ช่วงค่า LCA ของขวด PET 500mL หลายช่วง ไม่ได้บอกเลขเดียว 82.8g แบบตรง ๆ

และที่สำคัญ:

ถ้าผู้ใช้ใช้ reusable bottle ต้องคิดด้วยว่า reusable bottle เองมี environmental impact จากการผลิตและการล้าง

ดังนั้น:

0.08 kg → Medium confidence

ไม่ควรเป็น High แบบปัจจุบัน

6. ❌ Reuse a Plastic Bottle = 0.03 kg

0.08 × 1/3 เป็น assumption ที่คุณสร้างเอง

ดังนั้นผมจะเปลี่ยนเป็น:

Low confidence / not directly measurable

หรือเอา CO2 ออกจาก Quest นี้แล้วใช้ Points + Impact Level แทนก็ได้

7. Bring Your Own Shopping Bag

ค่า 0.02 kg มาจาก:

5.5g bag × 2 kgCO2e/kg plastic

คำนวณเลขได้ แต่ยังมีปัญหาว่า ถุง reusable ที่ผู้ใช้เอามาเองก็มี footprint

นอกจากนี้ยังต้องรู้ว่าถุงนั้นถูกใช้กี่ครั้ง

ดังนั้นควรเป็น:

Low–Medium confidence

ไม่ใช่ Medium อย่างเดียวโดยอัตโนมัติ

8. Refill Products

แนวคิดนี้แข็งแรงกว่าหลายรายการ เพราะญี่ปุ่นมีการใช้ refill packaging สูงจริง และกระทรวงสิ่งแวดล้อมญี่ปุ่นระบุว่า refill packs ใช้พลาสติกน้อยกว่าขวดประมาณ 70–80%

แต่จากตรงนั้นยัง ไม่ได้แปลโดยตรงว่า “ประหยัด 0.05 kgCO2e”

ดังนั้น:

Plastic reduction: มีหลักฐานดี
Exact CO2 reduction: ยังต้องใช้ product-specific LCA

ผมจะไม่เอา 0.05 ไปเรียกว่า exact CO2 saving

Recycling — ต้องระวังมาก
9. Sort Waste Correctly = 0.08

ตอนนี้คุณใช้:

250g × 0.3 kgCO2e/kg = 0.075

ปัญหาคือ 250g/day และ 0.3 kgCO2e/kg เป็น assumptions ที่ไม่ได้ถูกผูกกับ household ใน Ebetsu โดยตรง

งานวิจัยญี่ปุ่นที่คุณอ้างถึงเกี่ยวกับ plastic recycling เป็นการเปรียบเทียบ specific recycling/recovery pathways ไม่ได้แปลว่าขยะรีไซเคิลทุกชนิดใน Ebetsu มีค่า 0.3 kgCO2e/kg เท่ากัน

ดังนั้นผมแนะนำว่า:

Sort Waste Correctly → ไม่ควรมี static CO2 value ตอนนี้

หรือใช้:

“kg of waste correctly sorted”

เป็น metric แทน

10. Neighborhood Recycling Drive = 1.2

อันนี้ก็มี assumption หลายชั้น:

50kg / 15 people × 0.3

ทั้ง 50kg และ 0.3 factor ไม่ได้มาจากกิจกรรมจริงใน Ebetsu

ดังนั้นผมจะไม่เก็บ 1.2 kgCO2e เป็นค่าตายตัว

ทางที่แข็งแรงกว่าคือ:

kg recycled = actual amount collected

แล้วค่อยมี environmental impact estimate แยก หากมีข้อมูล LCA ที่เหมาะสม

Energy — ต้องแก้ตัวเลข
11. 0.4 kgCO2/kWh

อันนี้ผมแนะนำให้เปลี่ยนครับ

ในเอกสารใช้:

~0.4 kgCO2/kWh สำหรับ Hokkaido

แต่ Hokkaido Electric มีตัวเลขล่าสุดที่รายงานเองสำหรับ FY2025 เป็น:

0.536 kgCO2/kWh unadjusted
0.522 kgCO2/kWh adjusted

ดังนั้น 0.4 ต่ำไปพอสมควร

ตัวอย่าง Turn Off Unused Lights:

0.03 kW × 4 h = 0.12 kWh

0.12 × 0.522
≈ 0.063 kgCO2

ดังนั้นควรได้ประมาณ:

0.06 kgCO2

ไม่ใช่ 0.05 ถ้าใช้ factor ล่าสุดนี้

12. ❌ Tree Planting Day = 6.0 kgCO2

นี่คือจุดที่ผมอยากให้คุณ แก้แน่นอน

ในเอกสารเขียนว่า:

5.9 kgCO2/year สำหรับต้นอ่อน → ใช้ 6.0 เป็นค่า “ปีแรก”

แต่ source ของ One Tree Planted ที่คุณใช้เองระบุว่า methodology ของเขาให้ค่าเฉลี่ยประมาณ 10 kg CO2 ต่อต้นต่อปีในช่วง 20 ปีแรก และย้ำว่าการดูดซับขึ้นกับสถานที่ ชนิดต้นไม้ และสภาพการเติบโต

ดังนั้นคำว่า:

“6 kgCO2 = first year”

ไม่รองรับโดย source ที่คุณอ้าง

ผมแนะนำมากที่สุด:

อย่าเอา Tree Planting ไปนับรวมเป็น “CO2 Saved Now”

เพราะมันเป็น future carbon removal และขึ้นกับต้นรอดหรือไม่ สถานที่ และการเติบโต

เปลี่ยนเป็น:

Environmental Impact: High
CO2 Saved: Not directly counted

แล้วถ้าต้องการแสดงข้อมูลเสริม ค่อยบอกว่า:

“A planted tree may provide future carbon removal, depending on species and growing conditions.”

แบบนี้ปลอดภัยกว่าเยอะ

13. ❌ Community Cleanup = 2.0 kgCO2

ผมเห็นด้วยกับเอกสารเองในจุดนี้:

ยังไม่มีหลักฐานหนักแน่น

ดังนั้น อย่าใส่ 2.0

ผมแนะนำ:

CO2 Saved = 0 / Not calculated
Environmental Impact = High
Other impact = kg of litter collected

เพราะประโยชน์หลักของ Community Cleanup คือ ลด litter/pollution ไม่ใช่ GHG ที่คำนวณได้ง่าย

14. ปัญหาใหญ่ที่เอกสารยังไม่ได้พูดถึง: Double Counting

นี่สำคัญมากสำหรับ EcoQuest

ตอนนี้คุณกำลังจะเอา co2SavedKg ของแต่ละ Quest มารวมเป็น:

Total CO2 Saved

แต่ Quest หลายอันอาจนับ impact เดียวกันซ้ำ

ตัวอย่าง:

Finish Your Meal
       +
Food Saver — 7 Days

อาจกำลังนับการลด food waste ชุดเดียวกัน

หรือ:

Use a Reusable Bottle
+
Refill Your Water Bottle

อาจเป็น action เดียวกัน

และ:

Buy Refill Products
Use Refillable Laundry Detergent
Use Refillable Dish Soap

ก็มี overlap กันได้

ดังนั้น ไม่ควรเอา static CO2 ของทุก Quest มาบวกกันตรง ๆ

นี่เป็นปัญหาสำคัญกว่าการปรับ 0.05 เป็น 0.06 เสียอีก

ผมจะแก้โครงสร้างเอกสารเป็นแบบนี้
🟢 สามารถใช้เป็นตัวเลข estimate ได้
Finish Your Meal → แต่ต้องแก้ source interpretation
Energy quests → ใช้ current Hokkaido electricity factor
PET bottle → ใช้เป็น approximate LCA estimate
Food waste → ใช้ Japan data แทน UK
🟡 ใช้ได้ในฐานะ “estimated / potential impact”
Refill products
Shopping bag
Reusable bottle
Laundry detergent
Dish soap
Food containers
🔴 ยังไม่ควรใส่เป็น co2SavedKg
Check Your Food & Expiration Dates
Reuse a Plastic Bottle
Sort Waste Correctly
Neighborhood Recycling Drive
Community Cleanup
Tree Planting Day
สิ่งที่ผมแนะนำให้เปลี่ยนในระบบจริง

แทนที่จะมีแค่:

co2SavedKg

ผมแนะนำให้คิดเป็น:

environmentalImpact
impactCategory
co2eEstimateKg
impactMetric

ตัวอย่าง:

Community Cleanup
environmentalImpact: High
co2eEstimateKg: null
impactCategory: "Litter Removed"
impactMetric: "kg"

ส่วน Tree Planting:

environmentalImpact: High
co2eEstimateKg: null
impactCategory: "Tree Planted"
impactMetric: "trees"

Food Waste:

environmentalImpact: Medium
co2eEstimateKg: 0.12
impactCategory: "Food Waste Prevented"
impactMetric: "kg"

แบบนี้ EcoQuest จะไม่หลอกผู้ใช้ว่า “เราลด CO2 ได้เท่านี้แน่นอน” ในกรณีที่จริง ๆ แล้วเป็นเพียงผลกระทบทางสิ่งแวดล้อมด้านอื่น

สรุป

เอกสารนี้ ทำมาดีในด้านการรวบรวมแหล่งอ้างอิงและแสดงวิธีคำนวณ แต่ผมยังไม่แนะนำให้เอาตัวเลขทั้งหมดไปใส่ seedQuests.js ตอนนี้

สิ่งที่ต้องแก้ก่อนคือ:

1. ใช้ Japan data แทน UK สำหรับ Food Saver
2. แก้ Finish Your Meal จาก “64g/meal” เพราะ source รองรับ household/day มากกว่า
3. เอา 0.05 ของ Check Food ออกจาก CO2
4. ลดความมั่นใจของ plastic estimates
5. อย่าใช้ 0.3 kgCO2e/kg เป็น generic recycling factor
6. เปลี่ยน electricity factor 0.4 → ประมาณ 0.522/0.536 ตาม Hokkaido Electric ล่าสุด
7. แก้ Tree Planting 6kg “first year” เพราะ source ไม่รองรับข้อความนี้
8. เอา Community Cleanup 2kg ออกจาก CO2 calculation
9. ป้องกัน Double Counting ระหว่าง Quest
10. แยก “CO2e estimate” ออกจาก “Environmental Impact”

ที่สำคัญที่สุดคือ อย่าพยายามบังคับให้ทุก Quest ต้องมีค่า kgCO2e เพราะบางกิจกรรมสร้างประโยชน์ด้านสิ่งแวดล้อมที่วัดเป็น CO2 ได้ไม่ดี เช่น Cleanup, Sorting และ Tree Planting ในระยะสั้น การใช้ metric ที่ตรงกับ action จริงจะทำให้ EcoQuest น่าเชื่อถือกว่า
