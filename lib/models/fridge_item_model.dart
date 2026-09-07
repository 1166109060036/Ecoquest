// อาหารที่ผู้เล่นบันทึกไว้ในตู้เย็น (Mini Quest "Check Your Food & Expiration Dates")
// ตอนนี้ยังไม่ได้ต่อ backend FridgeItem API จริง ใช้ mock data ไปก่อน
// หมายเหตุ: ฝั่ง backend ใช้ชื่อฟิลด์ itemName / expirationDate / quantity
class FridgeItemModel {
  final String id;
  final String name;
  final DateTime expirationDate;
  final int quantity;
  // path ของรูปที่ผู้ใช้ถ่ายของจริงเก็บไว้ — null = ยังไม่มีรูป จะโชว์เป็นไอคอนอาหารแทน
  // TODO: ตอนต่อฟีเจอร์กล้องจริง ให้เก็บ path ของไฟล์รูปที่ถ่ายมาลงตรงนี้
  final String? photoPath;

  const FridgeItemModel({
    required this.id,
    required this.name,
    required this.expirationDate,
    required this.quantity,
    this.photoPath,
  });

  // เวลาที่เหลือก่อนหมดอายุ — ติดลบแปลว่าหมดอายุไปแล้ว
  Duration remainingFrom(DateTime now) => expirationDate.difference(now);

  bool isExpiredAt(DateTime now) => !expirationDate.isAfter(now);
}

// mock data — TODO: ดึงจาก GET /api/fridge-items จริงตอนมี endpoint
// ตั้งวันหมดอายุแบบอิงจากเวลาปัจจุบัน เพื่อให้เห็นครบทั้ง 3 แบบตอนเปิดหน้านี้:
// เหลือเกิน 1 วัน / เหลือไม่ถึง 24 ชม. (นับวินาทีถอยหลัง) / หมดอายุไปแล้ว
//
// ทุกตัวยัง photoPath = null เพราะยังไม่มีฟีเจอร์กล้อง ตอนนี้เลยขึ้นเป็นไอคอนอาหารทั้งหมด
// พอต่อกล้องเสร็จแล้วใส่ path รูปเข้ามา รูปจะขึ้นแทนไอคอนเองโดยไม่ต้องแก้โค้ดหน้าจอ
final List<FridgeItemModel> mockFridgeItems = [
  FridgeItemModel(
    id: 'milk',
    name: 'Milk',
    expirationDate: DateTime.now().add(const Duration(days: 2, hours: 5, minutes: 22)),
    quantity: 2,
  ),
  FridgeItemModel(
    id: 'bread',
    name: 'Bread',
    expirationDate: DateTime.now().add(const Duration(hours: 8, minutes: 14, seconds: 33)),
    quantity: 1,
  ),
  FridgeItemModel(
    id: 'eggs',
    name: 'Eggs',
    expirationDate: DateTime.now().add(const Duration(days: 5, hours: 1)),
    quantity: 10,
  ),
  FridgeItemModel(
    id: 'yogurt',
    name: 'Yogurt',
    expirationDate: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    quantity: 3,
  ),
];
