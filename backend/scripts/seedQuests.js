// สคริปต์ seed quest ตั้งต้นลง MongoDB
// รันด้วย: npm run seed:quests   (หรือ node scripts/seedQuests.js)
//
// เขียนแบบ upsert (อิงจาก title) — รันซ้ำได้ไม่สร้างของซ้ำ แค่อัปเดตค่าให้ตรงกับในไฟล์นี้
// ⚠️ ลบ quest ออกจากไฟล์นี้ "ไม่ได้" ลบออกจาก DB — ถ้าจะเอาออกจริงต้องไปลบใน DB เอง
//    หรือตั้ง isActive: false ให้มันแทน
//
// 📌 scorePoints ไม่ต้องกรอกเอง สคริปต์คำนวณจาก difficulty + impact ให้อัตโนมัติ
//    (easy/medium/hard = 5/10/15 บวกกับ low/medium/high = 5/10/15)
//
// 🌱 co2eEstimateKg / impactCategory / impactMetric / overlapGroup — ที่มาและวิธีคิดของทุกค่าอยู่ใน
//    CO2_RESEARCH.md (ข้อมูลญี่ปุ่น: food loss จาก MOE/CAA, ค่าไฟจาก Hokkaido Electric) ห้ามแก้ตัวเลขที่นี่
//    โดยไม่อัปเดตเอกสารนั้นด้วย — co2eEstimateKg: null = วัดเป็น CO2 ไม่ได้อย่างมีหลักฐาน (ไม่นับรวม)
//    ส่วน overlapGroup ต้องตรงกับ OVERLAP_DAILY_CAP_KG ใน utils/profilePayload.js
require('dotenv').config();
const mongoose = require('mongoose');
const Quest = require('../models/Quest');

const QUESTS = [
  // ---------------------------------------------------------------- food waste
  {
    title: 'Check Your Food & Expiration Dates',
    // ปักหมุดไว้บนสุดของ Explore ทุกวัน ไม่เข้าการสุ่มรายวัน (ผู้ใช้ตัดสินใจให้เป็นเควสหลักประจำวัน)
    // นับเป็น 1 ในโควต้า 4 เควสของผู้เล่นใหม่ ที่เหลือ 3 อันสุ่มใหม่ทุกวัน — ดู utils/questSelection.js
    alwaysVisible: true,
    sortOrder: 7,
    description: 'Food Waste Quest',
    // บอกวิธีทำให้ชัดในข้อความ — ผู้เล่นใหม่ไม่รู้ว่าต้องบันทึกของในตู้เย็นก่อนถึงจะจบเควสได้
    detail:
      'Open your fridge and record what is inside along with each expiration date. ' +
      'Knowing what needs to be eaten first is the simplest way to stop good food from being thrown away.\n\n' +
      'How to complete: tap Start, add your fridge items with their expiration dates, ' +
      'tap Save, then complete the quest.',
    imageKey: 'checkfridge.jpg',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: null,
    impactCategory: 'Food Inventory Checked',
    impactMetric: 'checks',
    overlapGroup: null,
    isDaily: true,
    // ต้องบันทึกของในตู้เย็นวันนี้ก่อน ถึงจะกดสำเร็จได้ (กดปุ่มเฉยๆ ไม่ให้คะแนน)
    actionKey: 'fridge_check',
  },
  {
    title: 'Finish Your Meal',
    sortOrder: 1,
    description: 'Food Waste Quest',
    detail:
      'Eat everything on your plate today. Taking only what you can finish is the easiest habit '
      + 'that keeps food out of the bin.',
    imageKey: 'finishyourmeal.jpg',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.05,
    impactCategory: 'Food Waste Prevented',
    impactMetric: 'days',
    overlapGroup: 'food_waste',
    isDaily: true,
  },
  {
    title: 'Use Leftover Ingredients',
    sortOrder: 8,
    description: 'Food Waste Quest',
    detail:
      'Cook a meal using ingredients that were about to go bad. '
      + 'Leftovers become a new dish instead of waste.',
    imageKey: 'useleftoveringredients.jpg',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.05,
    impactCategory: 'Food Waste Prevented',
    impactMetric: 'meals',
    overlapGroup: 'food_waste',
    isDaily: true,
  },

  // ------------------------------------------------------------------ recycling
  {
    title: 'Sort Waste Correctly',
    imageKey: 'sortwastecorrectly.jpg',
    sortOrder: 2,
    description: 'Recycling Quest',
    detail:
      'Separate your waste following the Ebetsu City sorting rules — burnable, plastic, '
      + 'cans, bottles and paper each go in their own bag. Correct sorting is what makes recycling actually work.',
    category: 'recycling',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: null,
    impactCategory: 'Waste Sorted Correctly',
    impactMetric: 'days',
    overlapGroup: null,
    isDaily: true,
  },
  {
    title: 'Reuse a Plastic Bottle',
    sortOrder: 9,
    description: 'Recycling Quest',
    detail:
      'Give a plastic bottle a second life before recycling it — use it as a water bottle, '
      + 'a storage container, or a plant pot.',
    imageKey: 'ReuseaPlasticBottle.jpg',
    category: 'recycling',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: null,
    impactCategory: 'Plastic Reused',
    impactMetric: 'bottles',
    overlapGroup: null,
    isDaily: true,
  },
  {
    // ผู้ใช้เลือกจากข่าว 6 ต.ค. 2026 (グリーンコープ共同体: สมาชิกส่งคืนภาชนะ 1,320,839 ชิ้น/เดือน ก.ค. 2026 — ของเล็กๆ
    // หลายคนรวมกันได้ผลจริง) ทำตอนไปซื้อของตามปกติ ไม่เสียเงิน — co2eEstimateKg: null (ยังไม่มีค่าต่อชิ้นที่มีที่มา)
    // proofForm = เก็บข้อมูลว่าคืนอะไร/กี่ชิ้น/ร้านไหน (utils/proofForm.js) → รวมเป็นแผนที่จุดรับคืนในเอเบ็ตสึได้ทีหลัง
    // ⚠️ ยังไม่มีรูปเควส (imageKey null = แอพโชว์ไอคอนแทน) — ใส่ชื่อไฟล์เมื่อมีรูปใน lib/utils/assets/questimg/
    title: 'Return Containers to the Store',
    sortOrder: 23,
    description: 'Recycling Quest',
    detail:
      'Rinse and dry food trays, milk cartons, egg packs or PET bottles, then drop them in a supermarket '
      + 'collection box (店頭回収) while you shop. Take a photo of your items at the box.',
    imageKey: null,
    category: 'recycling',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: null,
    impactCategory: 'Containers Returned',
    impactMetric: 'items',
    overlapGroup: null,
    isDaily: true,
    proofForm: {
      choiceLabel: 'What did you return?',
      choices: ['Food trays', 'Milk cartons', 'Egg packs', 'PET bottles', 'Other'],
      countLabel: 'How many items?',
      countMax: 50,
      placeLabel: 'Store name (optional)',
    },
  },

  // -------------------------------------------------------------------- plastic
  {
    title: 'Use a Reusable Bottle',
    // ⚠️ ปิดใช้งาน (1 ต.ค. 2026) — ใกล้เคียงกับ Reuse a Plastic Bottle เกินไป (ผู้ใช้ตัดสินใจ) ห้ามลบ object นี้:
    // seed upsert ด้วย title ลบออกเฉยๆ เควสใน DB จะเปิดใช้อยู่ต่อ / ช่องบนการ์ด Bingo ที่สุ่มไปแล้วกลายเป็นช่องฟรี (utils/bingo.js)
    isActive: false,
    sortOrder: 3,
    description: 'Plastic Reduction Quest',
    // รวม "Refill Your Water Bottle" เข้ามาแล้ว (การกระทำเดียวกัน) — ดูเควสนั้นด้านล่างที่ปิดใช้งานไว้
    detail:
      'Carry your own bottle today and refill it at home or at a water station, '
      + 'instead of buying a drink in a single-use plastic one.',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.08,
    impactCategory: 'Single-Use Plastic Avoided',
    impactMetric: 'bottles',
    overlapGroup: 'single_use_plastic',
    isDaily: true,
  },
  {
    title: 'Refill Your Water Bottle',
    // ⚠️ ปิดใช้งาน — ซ้ำกับ Use a Reusable Bottle (รวมเข้าไปแล้ว) ห้ามลบ object นี้ออกจากไฟล์: seed upsert ด้วย
    // title ลบออกเฉยๆ เควสเดิมใน DB จะยังเปิดใช้อยู่ตลอดไป ต้องคงไว้พร้อม isActive: false (ประวัติเดิมยังโชว์ชื่อได้)
    isActive: false,
    sortOrder: 10,
    description: 'Plastic Reduction Quest',
    detail:
      'Refill your bottle at a water station or at home instead of buying a new one while you are out.',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.08,
    impactCategory: 'Single-Use Plastic Avoided',
    impactMetric: 'bottles',
    overlapGroup: 'single_use_plastic',
    isDaily: true,
  },
  {
    title: 'Bring Your Own Shopping Bag',
    imageKey: 'bringyourownshopingbag.jpg',
    sortOrder: 11,
    description: 'Plastic Reduction Quest',
    detail: 'Take your own bag to the shop and refuse the plastic one at the counter.',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.01,
    impactCategory: 'Single-Use Plastic Avoided',
    impactMetric: 'bags',
    overlapGroup: 'single_use_plastic',
    isDaily: true,
  },
  {
    title: 'Buy Refill Products',
    imageKey: 'buyrefillproduct.jpg',
    sortOrder: 12,
    description: 'Plastic Reduction Quest',
    // คงชื่อเดิมไว้ (seed upsert ด้วย title — เปลี่ยนชื่อ = เควสใหม่ซ้อนกับอันเดิม) แต่จำกัดให้เป็นรีฟิลของอื่น
    // ไม่ทับกับน้ำยาซักผ้า/น้ำยาล้างจานที่มีเควสของตัวเอง
    detail:
      'Choose a refill pack instead of a brand new bottle for other everyday products, '
      + 'like shampoo, conditioner, body soap or hand soap. Refill packs use far less plastic '
      + 'for the same amount of product. (Laundry detergent and dish soap have their own quests.)',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.05,
    impactCategory: 'Plastic Packaging Reduced',
    impactMetric: 'refills',
    overlapGroup: null,
    // ⚠️ แก้บั๊ก balance: เดิมไม่มี isDaily เลย = ไม่มีด่านกันทำซ้ำอะไรเลยทั้ง POST /:id/start และ
    // POST /:id/complete (เช็คเฉพาะตอน isDaily === true เท่านั้น ดู routes/quests.js) กด Start→
    // Complete วนได้ไม่จำกัดรอบ ได้แต้มไม่มีเพดาน — ต้องตั้งเป็นรายวันเหมือนเควส solo อื่นทุกอัน
    isDaily: true,
  },
  {
    title: 'Use Refillable Laundry Detergent',
    sortOrder: 13,
    description: 'Plastic Reduction Quest',
    detail:
      'Refill your detergent container instead of buying a new plastic bottle. '
      + 'Detergent bottles are among the largest plastic items in a household.',
    imageKey: 'UseRefillableLaundryDetergent.jpg',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'medium',
    xpReward: 15,
    co2eEstimateKg: 0.07,
    impactCategory: 'Plastic Packaging Reduced',
    impactMetric: 'refills',
    overlapGroup: null,
    isDaily: true, // ดูเหตุผลที่คอมเมนต์ของ 'Buy Refill Products' ด้านบน — เดิมเควสนี้ทำซ้ำไม่จำกัดรอบได้
  },
  {
    title: 'Use Refillable Dish Soap',
    sortOrder: 14,
    description: 'Plastic Reduction Quest',
    detail: 'Refill your dish soap bottle rather than replacing it with a new one.',
    imageKey: 'UseRefillableDishSoap.jpg',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'medium',
    xpReward: 15,
    co2eEstimateKg: 0.04,
    impactCategory: 'Plastic Packaging Reduced',
    impactMetric: 'refills',
    overlapGroup: null,
    isDaily: true, // ดูเหตุผลที่คอมเมนต์ของ 'Buy Refill Products' ด้านบน — เดิมเควสนี้ทำซ้ำไม่จำกัดรอบได้
  },
  {
    title: 'Use Reusable Food Containers',
    imageKey: 'UseReusableFoodContainers.jpg',
    sortOrder: 4,
    description: 'Plastic Reduction Quest',
    detail:
      'Pack your food in reusable containers instead of disposable wrap or single-use boxes.',
    category: 'plastic',
    type: 'solo',
    difficulty: 'easy',
    impact: 'medium',
    xpReward: 15,
    co2eEstimateKg: 0.02,
    impactCategory: 'Single-Use Plastic Avoided',
    impactMetric: 'uses',
    overlapGroup: 'single_use_plastic',
    isDaily: true,
  },
  {
    title: 'Avoid Single-Use Plastic for One Day',
    imageKey: 'AvoidSingle-UsePlasticforOneDay.jpg',
    sortOrder: 6,
    description: 'Plastic Reduction Quest',
    detail:
      'Go a full day without using any single-use plastic — no plastic bags, straws, cutlery or bottles. '
      + 'Harder than it sounds, and it shows you exactly where plastic hides in your routine.',
    category: 'plastic',
    type: 'solo',
    difficulty: 'medium',
    impact: 'low',
    xpReward: 15,
    co2eEstimateKg: 0.12,
    impactCategory: 'Single-Use Plastic Avoided',
    impactMetric: 'days',
    overlapGroup: 'single_use_plastic',
    isDaily: true,
  },

  // --------------------------------------------------------------------- energy
  {
    title: 'Turn Off Unused Lights',
    sortOrder: 5,
    description: 'Energy Saving Quest',
    detail: 'Switch off the lights in rooms nobody is using.',
    imageKey: 'TurnOffUnusedLights.jpg',
    category: 'energy',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.06,
    impactCategory: 'Electricity Saved',
    impactMetric: 'days',
    overlapGroup: null,
    isDaily: true,
  },
  {
    title: 'Unplug Unused Devices',
    imageKey: 'UnplugUnusedDevices.jpg',
    sortOrder: 15,
    description: 'Energy Saving Quest',
    detail:
      'Unplug chargers and appliances you are not using. Devices left plugged in keep drawing '
      + 'standby power even when switched off.',
    category: 'energy',
    type: 'solo',
    difficulty: 'easy',
    impact: 'low',
    xpReward: 10,
    co2eEstimateKg: 0.06,
    impactCategory: 'Electricity Saved',
    impactMetric: 'days',
    overlapGroup: null,
    isDaily: true,
  },

  // ------------------------------------------------------------------------
  // 🎲 กลุ่มสุ่ม "food_saver" — ทั้ง 3 อันนี้จะโผล่แค่วันละ 1 อันเท่านั้น
  //    ระบบสุ่มจาก (userId + วันที่) เลยได้อันเดิมทั้งวัน ดึงรีเฟรชกี่ครั้งก็ไม่เปลี่ยน
  //    (กันคนรีเฟรชรัวๆ จนได้อันที่คะแนนสูงสุด) พอข้ามเที่ยงคืนถึงจะสุ่มใหม่
  // ------------------------------------------------------------------------
  {
    title: 'Food Saver — 1 Day',
    sortOrder: 16,
    description: 'Food Waste Quest',
    detail:
      'Get through today without throwing away any food. '
      + 'Take only what you can finish and keep leftovers for later.',
    imageKey: 'finishyourmeal.jpg',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'easy',
    impact: 'medium',
    xpReward: 15,
    co2eEstimateKg: 0.12,
    impactCategory: 'Food Waste Prevented',
    impactMetric: 'days',
    overlapGroup: 'food_waste',
    isDaily: true,
    randomPool: 'food_saver',
    poolWeight: 1, // สุ่มในกลุ่มถ่วงน้ำหนัก — เควสหลายวันโผล่บ่อยกว่า (utils/questSelection.js)
  },
  {
    title: 'Food Saver — 3 Days',
    sortOrder: 17,
    description: 'Food Waste Quest',
    detail:
      'Keep your food waste at zero for 3 days in a row. Check in on the Progress page once each day '
      + '— if you miss a day, the count starts over. You earn points every day you check in, plus a big bonus when all 3 days are done.',
    // เช็คอินวันละครั้ง 3 วันติด ได้รางวัลตอนครบ — ดู Quest.durationDays / POST /:id/complete
    durationDays: 3,
    // ใช้รูปเดียวกับ Finish Your Meal ตามที่ผู้ใช้ระบุ (ยังไม่มีรูปแยกของตัวเองในโฟลเดอร์ questimg)
    imageKey: 'finishyourmeal.jpg',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'medium',
    impact: 'medium',
    xpReward: 20,
    co2eEstimateKg: 0.35,
    impactCategory: 'Food Waste Prevented',
    impactMetric: 'days',
    overlapGroup: 'food_waste',
    isDaily: true,
    randomPool: 'food_saver',
    poolWeight: 2, // สุ่มในกลุ่มถ่วงน้ำหนัก — เควสหลายวันโผล่บ่อยกว่า (utils/questSelection.js)
  },
  {
    title: 'Food Saver — 7 Days',
    sortOrder: 18,
    description: 'Food Waste Quest',
    detail:
      'Keep your food waste at zero for 7 days in a row. Check in on the Progress page once each day '
      + '— if you miss a day, the count starts over. You earn points every day you check in, plus a big bonus when all 7 days are done.',
    durationDays: 7,
    // ใช้รูปเดียวกับ Finish Your Meal ตามที่ผู้ใช้ระบุ (ยังไม่มีรูปแยกของตัวเองในโฟลเดอร์ questimg)
    imageKey: 'finishyourmeal.jpg',
    category: 'food_waste',
    type: 'solo',
    difficulty: 'hard',
    impact: 'medium',
    xpReward: 25,
    co2eEstimateKg: 0.81,
    impactCategory: 'Food Waste Prevented',
    impactMetric: 'days',
    overlapGroup: 'food_waste',
    isDaily: true,
    randomPool: 'food_saver',
    poolWeight: 2, // สุ่มในกลุ่มถ่วงน้ำหนัก — เควสหลายวันโผล่บ่อยกว่า (utils/questSelection.js)
  },

  // ------------------------------------------------------------------------
  // 👥 Party quest (เควสกลุ่ม) — ผู้เล่นต้อง "สร้างห้อง" จาก quest พวกนี้ก่อน คนอื่นถึงจะเข้าร่วมได้
  //    (ดู backend/routes/party.js) ทำซ้ำได้วันละครั้งต่อคนเหมือน quest รายวันทั่วไป
  //    location/capacity ที่ใส่ไว้เป็นแค่ค่า default ให้ฟอร์มสร้างห้องดึงไปเติม
  //    ไม่มี eventDate ตรงนี้แล้ว เพราะวันเวลานัดเจอกันเป็นของแต่ละห้อง (Party.eventDate)
  // ------------------------------------------------------------------------
  {
    title: 'Community Cleanup',
    sortOrder: 19,
    description: 'Riverside Park',
    detail:
      'Join your neighbours to collect litter along the Ishikari river bank. '
      + 'Gloves and bags are provided — just bring yourself and a bit of energy.',
    imageKey: 'CommunityCleanup.jpg',
    category: 'community',
    type: 'party',
    difficulty: 'hard',
    impact: 'high',
    xpReward: 30,
    co2eEstimateKg: null,
    impactCategory: 'Litter Removed',
    impactMetric: 'events',
    overlapGroup: null,
    location: 'Riverside Park',
    capacity: 10,
  },
  {
    title: 'Tree Planting Day',
    // ⚠️ ปิดใช้งาน (5 ต.ค. 2026) — ผู้ใช้ตัดออก แทนที่ด้วย Local Nature Activity ด้านล่าง ห้ามลบ object นี้:
    // seed upsert ด้วย title ลบออกเฉยๆ เควสใน DB จะเปิดใช้อยู่ต่อ / ห้องปาร์ตี้เดิมของเควสนี้หายจากลิสต์เอง (routes/party.js กรอง isActive)
    isActive: false,
    sortOrder: 22,
    // ไม่มีไฟล์รูป — ต้องเป็น null ชัดๆ (upsert ไม่ลบค่าเก่า 'TreePlantingDay.png' ที่อาจค้างใน DB ให้)
    imageKey: null,
    description: 'Ebetsu City Park',
    detail:
      'Help plant young trees in the city park. Every tree planted keeps absorbing CO2 for decades, '
      + 'so this is one of the highest impact things a group can do in an afternoon.',
    category: 'community',
    type: 'party',
    difficulty: 'medium',
    impact: 'high',
    xpReward: 25,
    co2eEstimateKg: null,
    impactCategory: 'Trees Planted',
    impactMetric: 'events',
    overlapGroup: null,
    location: 'Ebetsu City Park',
    capacity: 30,
  },
  {
    // แทน Tree Planting Day (ผู้ใช้เพิ่ม 5 ต.ค. 2026) — รางวัลเท่าเดิม (medium + high = 25) สมดุลแต้มไม่เปลี่ยน
    title: 'Local Nature Activity',
    sortOrder: 20,
    description: 'Nopporo Forest Park',
    detail:
      'Spend an afternoon caring for local nature with your neighbours — a guided nature walk, '
      + 'tidying up a park trail, or helping with a conservation activity. '
      + "A chance to learn about Ebetsu's plants and wildlife together.",
    imageKey: 'LocalNatureActivity.jpg',
    category: 'community',
    type: 'party',
    difficulty: 'medium',
    impact: 'high',
    xpReward: 25,
    co2eEstimateKg: null,
    impactCategory: 'Nature Activities',
    impactMetric: 'events',
    overlapGroup: null,
    location: 'Nopporo Forest Park',
    capacity: 20,
  },
  {
    title: 'Neighborhood Recycling Drive',
    sortOrder: 21,
    description: 'Community Center',
    detail:
      'Collect and sort recyclables from around the neighbourhood together, '
      + 'and help neighbours who are not sure which bag things belong in.',
    imageKey: 'NeighborhoodRecyclingDrive.jpg',
    category: 'recycling',
    type: 'party',
    difficulty: 'medium',
    impact: 'medium',
    xpReward: 20,
    co2eEstimateKg: null,
    impactCategory: 'Recyclables Collected',
    impactMetric: 'events',
    overlapGroup: null,
    location: 'Community Center',
    capacity: 15,
  },
  {
    // ผู้ใช้เพิ่ม 7 ต.ค. 2026 (อยู่ใน Quest_list.md) — party quest ดูแลสวน/แปลงผักชุมชนด้วยกัน
    // medium + medium = 20 P (เท่า Recycling Drive) / หมวด community นับเหรียญ Community
    // ⚠️ ยังไม่มีรูปเควส (imageKey null = แอพโชว์ไอคอนแทน) — ใส่ชื่อไฟล์เมื่อมีรูปใน lib/utils/assets/questimg/
    title: 'Community Garden',
    sortOrder: 24,
    description: 'Community Garden',
    detail:
      'Spend an afternoon with your neighbours at a community garden — weeding, watering, planting seasonal '
      + 'vegetables or flowers, and turning plant scraps into compost. Learn to grow food locally together.',
    imageKey: null,
    category: 'community',
    type: 'party',
    difficulty: 'medium',
    impact: 'medium',
    xpReward: 20,
    co2eEstimateKg: null,
    impactCategory: 'Garden Activities',
    impactMetric: 'events',
    overlapGroup: null,
    location: 'Community Garden',
    capacity: 15,
  },

];

// แยกตัว seed ออกมาเป็นฟังก์ชัน เพื่อให้ server.js เรียกตอน boot ได้ด้วย
// (จำเป็นเพราะเครื่อง dev บางเน็ต เช่น wifi มหาลัย ต่อ Atlas ไม่ได้ — ให้ Render seed แทน)
async function seedQuests({ verbose = true } = {}) {
    for (const q of QUESTS) {
      // scorePoints คำนวณจาก difficulty + impact เสมอ ห้ามกรอกมือ (easy+low = 5+5 = 10)
      const scorePoints = Quest.calculateScore(q.difficulty, q.impact);
      const isActive = q.isActive !== false;

      const saved = await Quest.findOneAndUpdate(
        { title: q.title },
        { ...q, scorePoints, isActive },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );

      const flags = [
        saved.isDaily ? 'วันละครั้ง' : null,
        saved.actionKey ? `action=${saved.actionKey}` : null,
        saved.randomPool ? `กลุ่มสุ่ม=${saved.randomPool}` : null,
        saved.type === 'party' ? `อีเวนต์ ${saved.location} รับ ${saved.capacity} คน` : null,
        saved.isActive ? null : 'ปิดอยู่',
      ]
        .filter(Boolean)
        .join(', ');

      if (verbose) console.log(
        `${saved.isActive ? '✔' : '·'} ${saved.title.padEnd(38)}` +
          `[${saved.difficulty}+${saved.impact}] = ${String(saved.scorePoints).padStart(2)} points` +
          (flags ? `  (${flags})` : '')
      );
    }

  // ลบฟิลด์ co2SavedKg เดิม (ก่อนเปลี่ยนเป็น co2eEstimateKg) ที่ค้างอยู่ใน document เก่า — upsert ข้างบน
  // ลบให้ไม่ได้เพราะฟิลด์นี้ไม่อยู่ใน schema แล้ว ต้องปิด strict ให้ $unset ผ่าน (รันซ้ำได้ ไม่มีผลข้างเคียง)
  await Quest.updateMany({}, { $unset: { co2SavedKg: 1 } }, { strict: false });

  const active = await Quest.countDocuments({ isActive: true });
  const inactive = await Quest.countDocuments({ isActive: false });
  if (verbose) console.log(`\nเปิดใช้งานอยู่ ${active} quest | ปิดไว้ ${inactive} quest`);
  return active;
}

module.exports = { seedQuests };

// รันตรงๆ ด้วย `npm run seed:quests` — กรณีนี้ต้องต่อ/ตัด connection เอง
if (require.main === module) {
  (async () => {
    try {
      await mongoose.connect(process.env.MONGODB_URI);
      console.log('เชื่อม MongoDB Atlas สำเร็จ\n');
      await seedQuests({ verbose: true });
    } catch (err) {
      console.error('seed ไม่สำเร็จ:', err.message);
      process.exitCode = 1;
    } finally {
      await mongoose.disconnect();
    }
  })();
}
