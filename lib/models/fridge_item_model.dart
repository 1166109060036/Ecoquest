import 'dart:convert';
import 'dart:typed_data';

// อาหารที่ผู้เล่นบันทึกไว้ในตู้เย็น (Mini Quest "Check Your Food & Expiration Dates")
// ข้อมูลจริงจาก GET /api/fridge-items
// หมายเหตุ: ฝั่ง backend ใช้ชื่อฟิลด์ itemName / expirationDate / quantity / photoPath / photoUrl
class FridgeItemModel {
  final String id;
  final String name;
  final DateTime expirationDate;
  final int quantity;
  // ⚠️ ฟิลด์เก่า — path รูปในเครื่องของผู้ใช้เอง (ก่อนอัพโหลดรูปขึ้น server จริง) เก็บไว้เฉยๆ ให้ของเก่า
  // ที่เคยถ่ายไว้ยัง fallback โชว์รูปได้บนเครื่องเดิม ของใหม่ทุกชิ้นจะมี photoUrl แทนแล้วไม่ใช้ตัวนี้
  final String? photoPath;
  // URL เต็มของรูป (อัพขึ้น server แล้ว) — null = ไม่มีรูป หรือเป็นของเก่าที่มีแค่ photoPath
  final String? photoUrl;
  // server ลบรูปทิ้งแล้วเพราะของหมดอายุ (backend/utils/fridgePhotos.js) — ตัวรายการยังอยู่ให้ผู้ใช้ลบเอง
  final bool photoRemoved;
  // วันที่บันทึกเข้าตู้เย็น — ใช้เรียง "Date added" ในหน้า Fridge (backend เก่าไม่ส่งมา = null ไปอยู่ท้ายสุด)
  final DateTime? addedAt;

  const FridgeItemModel({
    required this.id,
    required this.name,
    required this.expirationDate,
    required this.quantity,
    this.photoPath,
    this.photoUrl,
    this.photoRemoved = false,
    this.addedAt,
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
      photoUrl: json['photoUrl'],
      photoRemoved: json['photoRemoved'] == true,
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '')?.toLocal(),
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
  // bytes ของรูปที่เพิ่งถ่าย/เลือกจาก image_picker — อ่านตรงๆ ไม่ copy ไปเก็บถาวรในเครื่องอีกต่อไป
  // (แนวเดียวกับ avatar's _pickAvatar()) เพราะจะอัพขึ้น server ทันทีตอนกด Save
  final Uint8List? photoBytes;
  final String? photoContentType; // 'image/jpeg' หรือ 'image/png'

  FridgeItemDraft({
    required this.name,
    required this.expirationDate,
    required this.quantity,
    this.photoBytes,
    this.photoContentType,
  });

  Map<String, dynamic> toJson() => {
        'itemName': name,
        // ⚠️ ต้อง toUtc() ก่อนเสมอ — DateTime เวลาเครื่องได้ string ไม่มีโซนเวลา ("...T23:59:59.000") แล้ว
        // backend บน Render (UTC) อ่านเป็น 23:59 UTC = วันถัดไปตามเวลาญี่ปุ่น วันหมดอายุเลยเลื่อนไป 1 วัน
        // (แบบเดียวกับ eventDate ใน party_service.dart / before ใน chat_service.dart)
        'expirationDate': expirationDate.toUtc().toIso8601String(),
        'quantity': quantity,
        if (photoBytes != null) 'photoBase64': base64Encode(photoBytes!),
        if (photoContentType != null) 'photoContentType': photoContentType,
      };
}
