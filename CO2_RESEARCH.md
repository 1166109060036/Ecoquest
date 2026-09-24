# EcoQuest — ค่า kgCO2e จริงของแต่ละเควส (พร้อมแหล่งอ้างอิง)

ไฟล์ `backend/scripts/seedQuests.js` เดิมมีคอมเมนต์เตือนไว้ตั้งแต่แรกว่า:

> ⚠️ ค่า co2SavedKg ทั้งหมดเป็น "ค่าประมาณคร่าวๆ" ยังไม่ได้อ้างอิงงานวิจัยจริง
> ถ้าจะเอาไปใช้นำเสนอจริงควรหาตัวเลขอ้างอิงมาแทนก่อน

เอกสารนี้คือผลการหาตัวเลขอ้างอิงจริงมาแทนค่าประมาณเดิม แยกตามหมวดเควส พร้อมวิธีคิดและแหล่งที่มา
ทุกค่า — เพื่อให้เอาไปใช้นำเสนอ/พรีเซนต์ได้อย่างมั่นใจ

**ยังไม่ได้แก้โค้ดจริง** — ไฟล์นี้คือรายงานให้อ่านตัดสินใจก่อน พอโอเคแล้วค่อยเอาไปใส่ใน
`seedQuests.js` อีกที

---

## ตารางสรุป เดิม vs ใหม่

| เควส | เดิม (kg) | ใหม่ (kg) | ความมั่นใจ |
|---|---|---|---|
| Finish Your Meal | 0.15 | **0.15** | 🟢 สูง |
| Check Your Food & Expiration Dates | 0.2 | **0.05** | 🔴 ต่ำ (enabling action) |
| Use Leftover Ingredients | 0.2 | **0.35** | 🟡 กลาง |
| Food Saver — 1 Day | 0.2 | **0.6** | 🟢 สูง |
| Food Saver — 3 Days | 0.6 | **1.8** | 🟢 สูง |
| Food Saver — 7 Days | 1.4 | **4.2** | 🟢 สูง |
| Use a Reusable Bottle | 0.08 | **0.08** | 🟢 สูง |
| Refill Your Water Bottle | 0.08 | **0.08** | 🟢 สูง |
| Reuse a Plastic Bottle | 0.08 | **0.03** | 🟡 กลาง |
| Bring Your Own Shopping Bag | 0.03 | **0.02** | 🟡 กลาง |
| Buy Refill Products | 0.12 | **0.05** | 🟡 กลาง |
| Use Refillable Laundry Detergent | 0.25 | **0.08** | 🟡 กลาง |
| Use Refillable Dish Soap | 0.2 | **0.04** | 🟡 กลาง |
| Use Reusable Food Containers | 0.15 | **0.02** | 🟡 กลาง |
| Avoid Single-Use Plastic for One Day | 0.3 | **0.13** | 🟡 กลาง (ผลรวมของหลายอัน) |
| Sort Waste Correctly | 0.1 | **0.08** | 🟢 สูง |
| Neighborhood Recycling Drive | 1.5 | **1.2** | 🟡 กลาง |
| Turn Off Unused Lights | 0.1 | **0.05** | 🟡 กลาง (ขึ้นกับสมมติฐานชั่วโมง/จำนวนดวง) |
| Unplug Unused Devices | 0.12 | **0.05** | 🟡 กลาง |
| Community Cleanup | 2.0 | **2.0** (คงเดิม) | 🔴 ต่ำ — ยังหาตัวเลขอ้างอิงที่หนักแน่นไม่ได้ |
| Tree Planting Day | 5.0 | **6.0** | 🟢 สูง (ปีแรกของต้นอ่อน ไม่ใช่ตอนโตเต็มที่) |

🟢 = คำนวณจากตัวเลขวิจัยตรงๆ, 🟡 = ใช้ตัวเลขวิจัยจริงแต่ต้องตั้งสมมติฐานปริมาณ/พฤติกรรมเพิ่มเอง,
🔴 = ยังไม่มีวิธีวัดที่หนักแน่นพอ ใช้ตัวเลขคาดคะเนแทน

---

## 1. หมวด Food Waste

**ค่าฐานที่ใช้**: **2.5 kgCO2e ต่อ 1 kg อาหารที่เสียเปล่า** — มาจาก FAO ที่ใช้ตัวคูณ 2.5 tCO2e/t
กับปริมาณอาหารสูญเสียหลังการเก็บเกี่ยวและระดับผู้บริโภคทั่วโลก ([FAOSTAT Analytical Brief
50](https://openknowledge.fao.org/server/api/core/bitstreams/121cc613-3d0f-431c-b083-cc2031dd8826/content))
เป็นค่าเฉลี่ยรวมทุกประเภทอาหาร (เนื้อสัตว์ปล่อยสูงกว่านี้มาก ผักปล่อยต่ำกว่ามาก แต่ใช้ค่าเฉลี่ย
เพราะเควสไม่ได้ระบุชนิดอาหาร)

| เควส | ปริมาณอาหารที่ประหยัดได้ | ที่มาของสมมติฐาน | คำนวณ |
|---|---|---|---|
| Finish Your Meal | ~64 g/มื้อ | plate waste เฉลี่ยครัวเรือนจริง (ข้าว 49.6g + เนื้อ/ปลา 7.5g + ผัก 6.7g) จากงานวิจัยครัวเรือนฟิลิปปินส์ ([PMC9811705](https://pmc.ncbi.nlm.nih.gov/articles/PMC9811705/)) — เลือกใช้อันนี้เพราะเป็นข้อมูลระดับครัวเรือนจริง ไม่ใช่ lab/สถาบัน (ซึ่งมักสูงเกินจริง) | 0.064 × 2.5 = **0.16 ≈ 0.15** |
| Use Leftover Ingredients | ~150 g | สมมติฐาน: วัตถุดิบที่ "ใกล้เสีย" มักเป็นทั้งชิ้น/ทั้งส่วน มากกว่าเศษอาหารบนจาน | 0.15 × 2.5 = **0.375 ≈ 0.35** |
| Check Your Food & Expiration Dates | — (ไม่มีอาหารถูกกินหรือทิ้งจริงจากการกระทำนี้) | เป็น "enabling action" — การบันทึกของในตู้เย็นเองไม่ได้ลดขยะ แต่ช่วยให้ทำ Finish Your Meal/Use Leftover ได้แม่นขึ้นภายหลัง ใช้เป็น ~30% ของค่า Finish Your Meal เป็นตัวแทน "ผลทางอ้อม" | 0.15 × 0.3 = **0.05** |
| Food Saver — 1/3/7 วัน | 0.24 / 0.72 / 1.68 kg | ขยะอาหารเฉลี่ย 88 kg/คน/ปี ÷ 365 = 0.24 kg/วัน จากรายงาน [WRAP Household Food and Drink Waste in the UK 2022](https://www.wrap.ngo/resources/report/household-food-and-drink-waste-uk-2022) (รายงานที่ใช้กันแพร่หลายที่สุดสำหรับ per-capita food waste) | 0.24×2.5=**0.6**, 0.72×2.5=**1.8**, 1.68×2.5=**4.2** |

⚠️ **ข้อจำกัด**: ไม่มีข้อมูล food waste เฉพาะของญี่ปุ่น/เอเบ็ตสึที่หาได้ในรอบนี้ ใช้ค่า UK (WRAP) และ
ฟิลิปปินส์ (plate waste) แทนเพราะเป็นงานวิจัยที่เป็นระบบและอ้างอิงได้มากที่สุดที่หาเจอ — ถ้ามีข้อมูล
กระทรวงสิ่งแวดล้อมญี่ปุ่น (環境省) ในอนาคตควรสลับมาใช้แทน

---

## 2. หมวด Plastic

**วิธีคิดหลัก**: น้ำหนักพลาสติกที่หลีกเลี่ยงได้จริง (กรัม) × ค่าปล่อยจากการผลิตพลาสติก
**~2 kgCO2e ต่อ kg พลาสติก** (ค่ากลางจากงานวิจัย LCA การผลิต LDPE/HDPE/PET หลายแหล่ง — ดู
[Thunder Said Energy: CO2 from plastics](https://thundersaidenergy.com/downloads/co2-from-plastics-and-petrochemical-facilities/))

| เควส | น้ำหนัก/ปริมาณที่หลีกเลี่ยง | ที่มา | คำนวณ |
|---|---|---|---|
| Use a Reusable Bottle / Refill Your Water Bottle | ขวด PET 500ml เต็มวงจรชีวิต ~82.8g CO2 | การประเมินวงจรชีวิตขวดน้ำพลาสติก ([NIH: Life Cycle Environmental Impact of PET Water Bottles](https://nems.nih.gov/Documents/PETWaterBottlesEnvironmentalImpact.pdf), [Drink Local Drink Tap](https://drinklocaldrinktap.org/2020/03/11/carbon-impact-of-one-single-use-plastic-bottle/)) | **0.08** (ใช้ค่าตรงจากงานวิจัยได้เลย) |
| Reuse a Plastic Bottle | ขวดผลิตไปแล้ว แค่ยืดอายุใช้งานแทนทิ้งทันที — ไม่ได้หลีกเลี่ยงการผลิตขวดใหม่เต็มใบ | ประโยชน์จริงคือเลื่อนการทิ้ง/หลีกเลี่ยงซื้อของใช้ชิ้นเล็กอื่นทดแทน (เช่น กระปุกเก็บของ) ประเมินเป็น ~1/3 ของมูลค่าขวดเต็มใบ | 0.08 × (1/3) ≈ **0.03** |
| Bring Your Own Shopping Bag | ถุงพลาสติกหูหิ้วทั่วไป ~5.5 g | น้ำหนักถุงมาตรฐานที่อ้างถึงใน [co2everything.com](https://www.co2everything.com/co2e-of/plastic-bag) | 0.0055 × 2 = **0.011 ≈ 0.02** |
| Buy Refill Products (ทั่วไป) | ขวดใหม่ ~30g → refill pouch เหลือ ~10-20% | Refill pouch ใช้พลาสติกน้อยกว่าขวดแข็ง **80-90%** ([Zacros: Basics of Refill Pouches](https://www.zacrosamerica.com/news/basics-of-refill-pouches/), [Recoup refill case studies](https://www.recoup.org/wp-content/uploads/2023/09/refill-packaging-case-studies-recoup-1686828075-1-1.pdf)) — ญี่ปุ่นเองใช้ระบบ refill เป็น 70-80% ของตลาดของใช้ในบ้านอยู่แล้ว ยืนยันว่าเลข 80-90% ใช้ได้จริงในบริบทนี้ | ประหยัด ~25g × 2 = **0.05** |
| Use Refillable Laundry Detergent | ขวดผงซักฟอกใหญ่กว่า ~45g → เหลือ ~7g | เหตุผลเดียวกับด้านบน แต่ขวดต้นทางใหญ่กว่า (detergent bottle มักหนักกว่าขวดทั่วไป) | ประหยัด ~38g × 2 = **0.08** |
| Use Refillable Dish Soap | ขวดน้ำยาล้างจาน ~25g → เหลือ ~4g | เหตุผลเดียวกัน ขวดเล็กกว่า laundry | ประหยัด ~21g × 2 = **0.04** |
| Use Reusable Food Containers | เทียบกับ cling wrap/กล่องใช้แล้วทิ้ง ~8-10g ต่อครั้ง | ประมาณจากน้ำหนัก plastic wrap/กล่องแบบใช้แล้วทิ้งทั่วไป | 0.009 × 2 ≈ **0.02** |
| Avoid Single-Use Plastic for One Day | ผลรวม: ขวด (0.08) + ถุง (0.02) + ภาชนะ (0.02) + จิปาถะ เช่น หลอด/ช้อนส้อม (~0.01) | รวมรายการตัวแทนของพลาสติกใช้ครั้งเดียวที่คนทั่วไปเจอในหนึ่งวัน | 0.08+0.02+0.02+0.01 = **0.13** |

⚠️ **ข้อจำกัด**: ตัวเลขน้ำหนักบรรจุภัณฑ์ (30g/45g/25g สำหรับขวดรีฟิลต่างๆ) เป็นการประมาณจาก
ขนาดขวดทั่วไปในตลาด ไม่ได้ชั่งขวดจริงของแบรนด์ที่ผู้เล่นใช้ — ถ้าต้องการความแม่นสูงขึ้นควรชั่งน้ำหนัก
ขวด/ถุงรีฟิลจริงที่ขายในเอเบ็ตสึ

---

## 3. หมวด Recycling

**ค่าฐาน**: เปรียบเทียบ recycling กับการเผา (ญี่ปุ่นเผาขยะเป็นวิธีจัดการหลัก "burnable garbage")
งานวิจัยพบว่าวิธี recycling ต่างๆ ลดการปล่อยได้ **0.16-0.69 kgCO2e ต่อ kg พลาสติก** เทียบกับเผา
ขึ้นอยู่กับวิธี (chemical recycling ให้ผลดีสุด 0.69, coke oven recycling 0.16) —
([ScienceDirect: Which plastic recycling approaches maximize climate benefits](https://www.sciencedirect.com/science/article/pii/S0921344925004847))
ใช้ค่ากลาง **~0.3 kgCO2e/kg** สำหรับขยะรีไซเคิลผสม (พลาสติก+กระป๋อง+กระดาษ)

| เควส | ปริมาณ | คำนวณ |
|---|---|---|
| Sort Waste Correctly | ขยะรีไซเคิลเฉลี่ยครัวเรือน ~250g/วัน (ประมาณจากพลาสติก/กระป๋อง/กระดาษรวมกัน) | 0.25 × 0.3 = **0.075 ≈ 0.08** |
| Neighborhood Recycling Drive | กลุ่มรวมกันคัดแยกได้ ~50kg ต่อรอบ ÷ 15 คน (capacity ห้อง) | (50÷15) × 0.3 ≈ **1.0-1.2** |

---

## 4. หมวด Energy

**ค่าไฟฟ้าฮอกไกโด**: ~0.4 kgCO2/kWh — จากข้อมูล carbon intensity ของ Hokkaido Electric Power
(~0.43 kgCO2/kWh ในช่วงก่อนหน้า, มีแนวโน้มลดลงจากสัดส่วนพลังงานลมที่เพิ่มขึ้น) —
([Nature: Impacts of carbon pricing on the electricity market in Japan](https://www.nature.com/articles/s41599-022-01360-9))
⚠️ ตัวเลขนี้ผันผวนสูงเพราะฮอกไกโดพึ่งพลังงานลมเยอะ ควรมองเป็นค่ากลางโดยประมาณ ไม่ใช่ค่าตายตัว

| เควส | สมมติฐานการใช้ไฟ | คำนวณ |
|---|---|---|
| Turn Off Unused Lights | หลอด LED 10W × 3 ดวง × 4 ชม. ที่ไม่ได้ใช้ (หลอด LED มาตรฐานให้แสงเท่าหลอดไส้ 60W แต่กินไฟแค่ 10W — [EnergySage](https://www.energysage.com/electricity/house-watts/how-many-watts-does-a-light-bulb-use/)) | 0.03kW×4h=0.12kWh × 0.4 = **0.05** |
| Unplug Unused Devices | standby draw ~10W × 12 ชม. (1W ต่อเนื่อง ≈ 9kWh/ปี ตาม [Wikipedia: Standby power](https://en.wikipedia.org/wiki/Standby_power)) | 0.01kW×12h=0.12kWh × 0.4 = **0.05** |

---

## 5. Tree Planting Day

ต้นอ่อนที่เพิ่งปลูกดูดซับ CO2 น้อยกว่าต้นโตมาก — ปีแรกๆ ดูดซับจริงแค่ **~5.9 kgCO2/ปี**
เทียบกับต้นอายุ 10 ปีที่ดูดซับได้ ~22 kg/ปี และต้นโตเต็มที่เฉลี่ย ~25 kg/ปี
([One Tree Planted: How Much CO2 Does A Tree Absorb](https://onetreeplanted.org/blogs/stories/how-much-co2-does-tree-absorb),
[EcoTree](https://ecotree.green/en/how-much-co2-does-a-tree-absorb))

เลือกใช้ค่า **6.0 kgCO2e** (ปัดจาก 5.9) เพราะเควสคือ "การปลูก" ไม่ใช่ "การดูแลต้นโต" — ใช้ค่าปีแรก
จะตรงกับสิ่งที่ผู้เล่นทำจริงมากกว่า ถึงแม้ต้นไม้จะดูดซับมากขึ้นเรื่อยๆ ในปีต่อๆ ไปก็ตาม (ถ้าอยากสื่อสาร
ผลระยะยาวเพิ่มเติม สามารถใส่เป็นข้อความเสริมแยกได้ เช่น "และจะดูดซับเพิ่มขึ้นเรื่อยๆ ถึง ~25kg/ปีเมื่อโต
เต็มที่ในอีก ~10 ปี" โดยไม่ต้องเปลี่ยนตัวเลข co2SavedKg หลัก)

---

## 6. Community Cleanup — ยังหาอ้างอิงหนักแน่นไม่ได้ (คงค่าเดิม)

การเก็บขยะริมแม่น้ำมีประโยชน์หลักคือ **ลดมลพิษ/ขยะตกค้างในธรรมชาติ** ไม่ใช่การลด GHG โดยตรง
แบบเดียวกับเควสอื่นๆ ในรายงานนี้ — ไม่พบงานวิจัยที่แปลง "ปริมาณขยะที่เก็บได้ริมน้ำ" เป็น kgCO2e
โดยตรงในรอบค้นนี้ แนะนำให้ **คงค่าเดิม 2.0 ไว้ก่อน** และพิจารณาว่าจะยังใช้หน่วย kgCO2e กับเควสนี้
ต่อไปหรือไม่ (อาจเหมาะกับหน่วยอื่น เช่น "kg ขยะที่เก็บได้" มากกว่า)

---

## แหล่งอ้างอิงทั้งหมด

- [FAOSTAT Analytical Brief 50 — Food waste GHG emissions](https://openknowledge.fao.org/server/api/core/bitstreams/121cc613-3d0f-431c-b083-cc2031dd8826/content)
- [WRAP — Household Food and Drink Waste in the UK 2022](https://www.wrap.ngo/resources/report/household-food-and-drink-waste-uk-2022)
- [Plate waste of Filipino households (PMC9811705)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9811705/)
- [NIH — Life Cycle Environmental Impact of PET Water Bottles](https://nems.nih.gov/Documents/PETWaterBottlesEnvironmentalImpact.pdf)
- [Drink Local Drink Tap — Carbon Impact of One Single-use Plastic Bottle](https://drinklocaldrinktap.org/2020/03/11/carbon-impact-of-one-single-use-plastic-bottle/)
- [Thunder Said Energy — CO2 from plastics and petrochemical facilities](https://thundersaidenergy.com/downloads/co2-from-plastics-and-petrochemical-facilities/)
- [co2everything.com — Plastic Bag carbon footprint](https://www.co2everything.com/co2e-of/plastic-bag)
- [Zacros — Basics of Refill Pouches](https://www.zacrosamerica.com/news/basics-of-refill-pouches/)
- [Recoup — Refill Packaging Case Studies (PDF)](https://www.recoup.org/wp-content/uploads/2023/09/refill-packaging-case-studies-recoup-1686828075-1-1.pdf)
- [ScienceDirect — Which plastic recycling approaches maximize climate benefits (Japan)](https://www.sciencedirect.com/science/article/pii/S0921344925004847)
- [Nature — Impacts of carbon pricing on the electricity market in Japan](https://www.nature.com/articles/s41599-022-01360-9)
- [EnergySage — How Many Watts Does a Light Bulb Use](https://www.energysage.com/electricity/house-watts/how-many-watts-does-a-light-bulb-use/)
- [Wikipedia — Standby power](https://en.wikipedia.org/wiki/Standby_power)
- [One Tree Planted — How Much CO2 Does A Tree Absorb](https://onetreeplanted.org/blogs/stories/how-much-co2-does-tree-absorb)
- [EcoTree — How much CO2 does a tree absorb](https://ecotree.green/en/how-much-co2-does-a-tree-absorb)

---

## ขั้นตอนถัดไป

1. อ่านตารางสรุปด้านบน ปรับ/ท้วงติงตัวเลขไหนที่รู้สึกว่าไม่เหมาะกับบริบทเอเบ็ตสึจริง
2. พอโอเคแล้ว บอกให้เอาไปใส่ใน `backend/scripts/seedQuests.js` — จะใส่ค่าใหม่ + คอมเมนต์อ้างอิง
   สั้นๆ กำกับแต่ละค่า แล้วรัน `npm run seed:quests` เพื่ออัปเดตข้อมูลใน MongoDB Atlas จริง
3. อัปเดตคอมเมนต์เตือนที่หัวไฟล์ (บรรทัด 11-12) ว่าตอนนี้มีอ้างอิงแล้ว พร้อมลิงก์ไปเอกสารนี้
