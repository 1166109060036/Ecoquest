EcoQuest — งานที่ต้องทำต่อ

ตอนนี้ระบบหลักของ EcoQuest ถูกพัฒนาและเชื่อมกับ Backend จริงแล้ว ดังนั้นงานต่อไปไม่ใช่การเพิ่มฟีเจอร์จำนวนมาก แต่คือ ทดสอบและปรับสมดุลของระบบเกม ให้เหมาะสมก่อนนำไปทดสอบกับผู้ใช้จริง

1. ทดสอบ Point Balance

ระบบ Quest ปัจจุบันให้ 10–30 Points ต่อ Quest โดยคำนวณจาก Difficulty + Impact

ให้จำลองผู้เล่น 3 แบบ:

Player	Quests / Day
Casual	1
Normal	3
Active	5

คำนวณว่าแต่ละแบบจะมี Points เท่าไรหลัง:

7 วัน / 14 วัน / 30 วัน

ใช้ค่า Quest ต่ำสุด 10 P, ค่าเฉลี่ย 20 P และสูงสุด 30 P

จุดประสงค์คือดูว่า ผู้เล่นหา Points ได้เร็วหรือช้าเกินไปหรือไม่

2. ทดสอบ Item Shop

Item ปัจจุบัน:

Item	Price	Effect
Red Energy	40 P	2× Quest Points / 30 min
Blue Energy	40 P	2× Quest XP / 30 min
Green Energy	40 P	2× Party Quest Points / 30 min
Super Energy	100 P	ทำ Daily Quest ที่ทำไปแล้วซ้ำได้

รายละเอียด Item และราคาอยู่ในระบบปัจจุบันแล้ว แต่ ราคาและ Effect ยังต้องผ่านการทดสอบ Balance จริง

ให้ทดสอบว่าแต่ละ Item:

ราคา → ประโยชน์ที่ได้รับ → ใช้เวลานานแค่ไหนถึงจะคุ้ม

ตัวอย่าง:

Red Energy 40 P
ถ้า Quest เฉลี่ย 20 P:

1 Quest → ได้เพิ่ม 20 P
2 Quests → ได้เพิ่ม 40 P = คืนทุน
3 Quests → ได้เพิ่ม 60 P = ได้กำไร 20 P

ดังนั้นต้องทดลองว่า ผู้เล่นทั่วไปทำกี่ Quest ได้ภายใน 30 นาที

3. ทดสอบ Super Energy เป็นพิเศษ

Super Energy ราคา 100 P และทำให้ Quest ที่ทำวันนี้กลับมาทำซ้ำได้

สมมติ Quest เฉลี่ย 20 P:

100 ÷ 20 = 5 Quests

ดังนั้นต้องตรวจว่า หลังใช้ Super Energy แล้ว ผู้เล่นสามารถทำ Quest เพิ่มได้กี่อัน

ถ้าเพิ่มได้เพียง 1–2 Quest → Item อาจมีราคาสูงเกินไป
ถ้าเพิ่มได้ประมาณ 5 Quest หรือมากกว่า → ราคาเริ่มสมเหตุสมผล

4. ทดสอบ Ability Upgrade

ปัจจุบันมี:

Point Booster
XP Booster
Party Bonus Points
Quest Unlock

แต่ละ Level เพิ่มผล 1% และซื้อเพิ่มได้หลายระดับ

ต้องทดสอบว่า:

ผู้เล่นใช้เวลานานแค่ไหนกว่าจะซื้อ Upgrade ได้ และ Upgrade นั้นให้ประโยชน์มากเกินไปหรือน้อยเกินไป

โดยเฉพาะ Point Booster เพราะสามารถทำให้ผู้เล่นหา Points ได้เร็วขึ้น และกระทบ Item Shop โดยตรง

5. ปรับ Balance

หลังจากทดลองแล้ว ให้เลือกว่าจะ:

Keep — คงค่าเดิม
Increase Price — เพิ่มราคา
Decrease Price — ลดราคา
Change Effect — เปลี่ยนผลของ Item/Upgrade

หลักสำคัญคือ:

Points ควรมีคุณค่ามากพอให้ผู้เล่นอยากทำ Quest แต่ไม่ควรหาได้ง่ายจน Item Shop และ Upgrade ไม่มีความหมาย

6. ตรวจ Daily Streak

ระบบ Daily Streak ปัจจุบันใช้การทำ Quest อย่างน้อย 1 ครั้งต่อวัน และมีรางวัลที่ milestone ต่าง ๆ

ตรวจสอบว่า:

7 Days → Small Reward
14 Days → Medium Reward
21 Days → Reward
30 Days → Biggest Reward + Special Item

เป้าหมายคือทำให้ผู้ใช้มีเหตุผลที่จะกลับมาใช้แอปต่อเนื่อง โดยไม่ทำให้รางวัลแจกง่ายเกินไป

7. User Testing

เมื่อ Balance เบื้องต้นเรียบร้อยแล้ว ให้คนที่ไม่เคยใช้ EcoQuest ประมาณ 3–5 คน ทดลองเล่น

ให้เวลาประมาณ 15–20 นาที และไม่ต้องอธิบายระบบทั้งหมดก่อน

หลังทดลองถาม:

What do you think this app is for?
Why did you want to complete the quests?
What made you want to continue playing?
What do you think Points are used for?
Which feature did you like the most?

จุดสำคัญที่สุดคือหาให้ได้ว่า อะไรทำให้คนอยากทำ Environmental Quest

8. เก็บ Feedback

ทำตารางสรุป:

Feedback	Users	Action
ไม่เข้าใจ Item	3/5	ปรับคำอธิบาย
อยากทำ Quest ต่อ	4/5	Keep
Points เข้าใจง่าย	5/5	Keep
Streak น่าสนใจ	4/5	Keep

จากนั้นแบ่งปัญหาเป็น:

Must Fix → Should Fix → Nice to Have

9. Final Revision

นำ Feedback จากผู้ใช้มาปรับ:

Quest → Points → Items / Upgrade → Daily Streak → Continued Usage

แล้วทดสอบอีกครั้งเพื่อให้แน่ใจว่าระบบทั้งหมดทำงานร่วมกันได้ดี

เป้าหมายสุดท้าย

เมื่อทำขั้นตอนทั้งหมดเสร็จ EcoQuest จะไม่ได้เป็นเพียงแอปที่ “ระบบทำงานได้” แต่สามารถอธิบายได้ว่า:

ระบบเกมถูกออกแบบอย่างไร → ทดสอบอย่างไร → ผู้ใช้ตอบสนองอย่างไร → และปรับปรุงจากข้อมูลอย่างไร

ลำดับการทำงานที่แนะนำ:

Point Balance → Item Balance → Upgrade Balance → Daily Streak → User Testing → Feedback → Final Revision