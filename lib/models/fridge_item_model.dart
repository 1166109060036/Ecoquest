// อาหารที่ผู้เล่นบันทึกไว้ในตู้เย็น (Mini Quest "Check Your Food & Expiration Dates")
// ข้อมูลจริงจาก GET /api/fridge-items
// หมายเหตุ: ฝั่ง backend ใช้ชื่อฟิลด์ itemName / expirationDate / quantity / photoPath
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

  factory FridgeItemModel.fromJson(Map<String, dynamic> json) {
    return FridgeItemModel(
      id: (json['id'] ?? '').toString(),
      name: json['itemName'] ?? '',
      // เก็บใน DB เป็น UTC — แปลงเป็นเวลาเครื่องก่อน ไม่งั้นเวลานับถอยหลังจะเพี้ยนตามโซนเวลา
      expirationDate:
          DateTime.tryParse(json['expirationDate']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      quantity: json['quantity'] ?? 1,
      photoPath: json['photoPath'],
    );
  }

  // เวลาที่เหลือก่อนหมดอายุ — ติดลบแปลว่าหมดอายุไปแล้ว
  Duration remainingFrom(DateTime now) => expirationDate.difference(now);

  bool isExpiredAt(DateTime now) => !expirationDate.isAfter(now);
}

// ของที่ผู้ใช้เพิ่งกรอกในหน้า Fridge แต่ยังไม่ได้กด Save (ยังไม่มี id จาก server)
// รวบไว้เป็นชุดแล้วส่งทีเดียวตอนกด Save ตามที่ backend รองรับ (POST รับเป็น array)
class FridgeItemDraft {
  final String name;
  final DateTime expirationDate;
  final int quantity;
  // path รูปที่เพิ่งถ่ายจาก image_picker (อยู่ในโฟลเดอร์ cache ของแอพ)
  final String? photoPath;

  FridgeItemDraft({
    required this.name,
    required this.expirationDate,
    required this.quantity,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'itemName': name,
        'expirationDate': expirationDate.toIso8601String(),
        'quantity': quantity,
        'photoPath': photoPath,
      };
}
