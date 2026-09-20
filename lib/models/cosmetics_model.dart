// ของตกแต่งโปรไฟล์ที่ user คนหนึ่ง "ใส่อยู่ตอนนี้" — คนละเรื่องกับความเป็นเจ้าของ (ดู
// InventoryItemModel.slot) ค่าที่เก็บคือ itemType ตรงจาก backend/utils/inventory.js#ITEMS
// null = ไม่ได้ใส่ช่องนั้น มาพร้อม user ทุกจุดที่โชว์ตัวตนให้คนอื่นเห็น (auth/me, users/:id,
// สมาชิกปาร์ตี้, เพื่อน) — ดูหน้าตาจริงของแต่ละ itemType ที่ lib/utils/cosmetics.dart
class EquippedCosmetics {
  final String? frame;
  final String? nameStyle;
  final String? background;
  final String? effect;

  const EquippedCosmetics({this.frame, this.nameStyle, this.background, this.effect});

  factory EquippedCosmetics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EquippedCosmetics();
    return EquippedCosmetics(
      frame: json['frame'],
      nameStyle: json['nameStyle'],
      background: json['background'],
      effect: json['effect'],
    );
  }

  Map<String, dynamic> toJson() => {
        'frame': frame,
        'nameStyle': nameStyle,
        'background': background,
        'effect': effect,
      };
}
