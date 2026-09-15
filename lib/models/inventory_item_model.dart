import 'package:flutter/material.dart';

// ไอเทมที่เก็บไว้ในกระเป๋าของผู้เล่น — ข้อมูลจริงจาก GET /api/inventory
// backend ส่งมาแค่ itemType/title/description/quantity/cost ส่วนไอคอน/สีเป็นเรื่องของฝั่งแอพ
// (แนวเดียวกับ AchievementMedalModel.icon ใน achievement_model.dart)
class InventoryItemModel {
  final String itemType; // 'camera' / 'fridge' / 'red_energy' / ... — คีย์ที่ backend ใช้ระบุชนิดไอเทม
  final String title;
  final String description;
  // จำนวนที่มีอยู่จริง (0 = ยังไม่มี/ยังไม่ได้ซื้อ) — backend ส่งไอเทมที่ซื้อได้ทุกอันมาเสมอแม้ quantity
  // จะเป็น 0 เพื่อให้การ์ดร้านค้าในหน้า Profile ใช้ข้อมูลชุดเดียวกันนี้ได้ ไม่ต้องมี endpoint แยก
  final int quantity;
  final int? cost; // ราคาซื้อ 1 ชิ้นเป็น Points — null = ซื้อไม่ได้ (starter item อย่าง Camera/Fridge)

  const InventoryItemModel({
    required this.itemType,
    required this.title,
    required this.description,
    this.quantity = 0,
    this.cost,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      itemType: json['itemType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      quantity: json['quantity'] ?? 0,
      cost: json['cost'],
    );
  }

  // ไอเทม Energy กดใช้ได้จากหน้า Inventory (ตั้งค่า/รีเซ็ทเควส) — starter item อย่าง Camera/Fridge กดใช้ไม่ได้
  // ต้องกดเข้าหน้าฟีเจอร์ของมันแทน (ดู _routeFor ใน inventory_page.dart)
  bool get isUsable => switch (itemType) {
        'red_energy' || 'blue_energy' || 'green_energy' || 'super_energy' => true,
        _ => false,
      };

  // fallback ถ้าไม่มี imageAsset หรือหาไฟล์รูปไม่เจอ
  IconData get icon => switch (itemType) {
        'camera' => Icons.camera_alt,
        'fridge' => Icons.kitchen,
        'eco_badge' => Icons.military_tech,
        'red_energy' || 'blue_energy' || 'green_energy' => Icons.bolt,
        'super_energy' => Icons.auto_awesome,
        _ => Icons.inventory_2,
      };

  // สีไอคอน/พื้นหลังของไอเทม Energy แต่ละสี — ใช้ทั้งการ์ดใน Inventory และการ์ดร้านค้าในหน้า Profile
  Color get accentColor => switch (itemType) {
        'eco_badge' => Colors.amber.shade800,
        'red_energy' => Colors.redAccent,
        'blue_energy' => Colors.blueAccent,
        'green_energy' => Colors.greenAccent.shade700,
        'super_energy' => Colors.amber.shade700,
        _ => Colors.black87,
      };

  // path รูปจริงของไอเทม ถ้ามี — ใช้แทน icon
  // ⚠️ Eco Badge + ไอเทม Energy ทั้ง 4 เว้นชื่อไฟล์ไว้ล่วงหน้าแล้ว (ยังไม่มีไฟล์รูปจริง) — วางไฟล์ชื่อตรงกัน
  // นี้ลงใน lib/utils/assets/items/ ได้เลยไม่ต้องแก้โค้ด/pubspec เพิ่ม (ประกาศเป็นโฟลเดอร์ไว้แล้ว) ระหว่างที่
  // ยังไม่มีไฟล์ Image.errorBuilder ใน InventoryCard จะ fallback ไปโชว์ icon/accentColor ด้านบนแทนเอง
  String? get imageAsset => switch (itemType) {
        'camera' => 'lib/utils/assets/items/camera.png',
        'fridge' => 'lib/utils/assets/inventory/fridge.png',
        'eco_badge' => 'lib/utils/assets/items/eco_badge.png',
        'red_energy' => 'lib/utils/assets/items/red_energy.png',
        'blue_energy' => 'lib/utils/assets/items/blue_energy.png',
        'green_energy' => 'lib/utils/assets/items/green_energy.png',
        'super_energy' => 'lib/utils/assets/items/super_energy.png',
        _ => null,
      };
}
