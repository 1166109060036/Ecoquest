import 'package:flutter/material.dart';

// การแจ้งเตือนที่แสดงในหน้า Notification
// ตอนนี้ยังไม่ได้ต่อ backend จริง ใช้ mock data ไปก่อน
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final IconData icon; // fallback ถ้าหาไฟล์รูปไม่เจอ (ยังไม่ได้ใส่รูป/ลืมประกาศใน pubspec)
  final Color iconColor;
  final String? imageAsset; // path รูปจริง ถ้ามี — ใช้แทน icon

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    this.iconColor = Colors.black87,
    this.imageAsset,
  });
}

// mock data — TODO: ดึงจาก backend จริงตอนมี endpoint แจ้งเตือน
final List<NotificationModel> mockNotifications = [
  NotificationModel(
    id: 'quest_complete',
    title: 'Quest Complete!',
    message: 'The Quest Complete You have received 10 points.',
    icon: Icons.emoji_events,
    iconColor: Colors.amber,
    imageAsset: 'lib/utils/assets/notifications/trophy.png',
  ),
  NotificationModel(
    id: 'almost_expired',
    title: 'Almost Expired',
    message: 'Your bread expires on 5/9/2026 only 24 hours remain.',
    icon: Icons.kitchen,
    iconColor: Colors.blueGrey,
    imageAsset: 'lib/utils/assets/notifications/fridge_expired.png',
  ),
];
