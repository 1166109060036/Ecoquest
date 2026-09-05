import 'package:flutter/material.dart';

// ไอเทมที่เก็บไว้ในกระเป๋าของผู้เล่น
// ตอนนี้ยังไม่ได้ต่อ backend InventoryItem API จริง ใช้ mock data ไปก่อน
class InventoryItemModel {
  final String id;
  final String title;
  final String description;
  final IconData icon; // fallback ถ้าไม่มี imageAsset หรือหาไฟล์รูปไม่เจอ
  final String? imageAsset; // path รูปจริงของไอเทม ถ้ามี — ใช้แทน icon
  final int? quantity; // null = ไม่แสดง badge จำนวน (ไอเทมที่มีได้แค่ชิ้นเดียว)

  const InventoryItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.imageAsset,
    this.quantity,
  });
}

// mock data — TODO: ดึงจาก GET /api/inventory จริงตอนมี endpoint
// Fridge ที่นี่คือทางเข้าไปดู fridgeItems (Mini Quest เช็คอาหาร/วันหมดอายุ)
// ยังไม่ได้ทำหน้ารายละเอียดจริง — แค่กดเข้าได้ก่อนตามที่ตกลงกันไว้
final List<InventoryItemModel> mockInventoryItems = [
  InventoryItemModel(
    id: 'camera',
    title: 'Camera',
    description: 'Take photos to capture good moments.',
    icon: Icons.camera_alt,
    imageAsset: 'lib/utils/assets/items/camera.png',
    quantity: 1,
  ),
  InventoryItemModel(
    id: 'fridge',
    title: 'Fridge',
    description: 'View saved food items and their expiration dates.',
    icon: Icons.kitchen,
    quantity: 1,
  ),
];
