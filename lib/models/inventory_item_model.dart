import 'package:flutter/material.dart';

// ไอเทมที่เก็บไว้ในกระเป๋าของผู้เล่น — ข้อมูลจริงจาก GET /api/inventory
// backend ส่งมาแค่ itemType/title/description/quantity ส่วนไอคอน/รูปเป็นเรื่องของฝั่งแอพ
// (แนวเดียวกับ AchievementMedalModel.icon ใน achievement_model.dart)
class InventoryItemModel {
  final String itemType; // 'camera' / 'fridge' — คีย์ที่ backend ใช้ระบุชนิดไอเทม
  final String title;
  final String description;
  final int? quantity; // null = ไม่แสดง badge จำนวน (ไอเทมที่มีได้แค่ชิ้นเดียว)

  const InventoryItemModel({
    required this.itemType,
    required this.title,
    required this.description,
    this.quantity,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      itemType: json['itemType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      quantity: json['quantity'],
    );
  }

  // fallback ถ้าไม่มี imageAsset หรือหาไฟล์รูปไม่เจอ
  IconData get icon => switch (itemType) {
        'camera' => Icons.camera_alt,
        'fridge' => Icons.kitchen,
        _ => Icons.inventory_2,
      };

  // path รูปจริงของไอเทม ถ้ามี — ใช้แทน icon
  String? get imageAsset => switch (itemType) {
        'camera' => 'lib/utils/assets/items/camera.png',
        'fridge' => 'lib/utils/assets/inventory/fridge.png',
        _ => null,
      };
}
