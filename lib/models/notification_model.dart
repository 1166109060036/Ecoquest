import 'package:flutter/material.dart';

// การแจ้งเตือนที่แสดงในหน้า Notification — ข้อมูลจริงจาก GET /api/notifications
// backend ส่งมาแค่ type + title/message ที่เขียนสำเร็จรูปมาแล้ว ส่วนไอคอน/รูปเป็นเรื่องของฝั่งแอพ
// (แนวเดียวกับ InventoryItemModel.icon ใน inventory_item_model.dart)
class NotificationModel {
  final String id;
  final String type; // quest_complete / fridge_expiring / achievement
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      // createdAt ควรมีเสมอ แต่กันไว้เผื่อข้อมูลเก่าที่ไม่มีค่านี้ ไม่ให้ทั้งลิสต์พัง
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  // fallback ถ้าหาไฟล์รูปไม่เจอ (ยังไม่ได้ใส่รูป/ลืมประกาศใน pubspec)
  IconData get icon => switch (type) {
        'quest_complete' => Icons.emoji_events,
        'fridge_expiring' => Icons.kitchen,
        'achievement' => Icons.military_tech,
        _ => Icons.notifications,
      };

  Color get iconColor => switch (type) {
        'quest_complete' => Colors.amber,
        'fridge_expiring' => Colors.blueGrey,
        'achievement' => Colors.purple,
        _ => Colors.black87,
      };

  // path รูปจริง ถ้ามี — ใช้แทน icon (ยังไม่มีรูปเหรียญ Achievement เลยใช้ icon ไปก่อน)
  String? get imageAsset => switch (type) {
        'quest_complete' => 'lib/utils/assets/notifications/trophy.png',
        'fridge_expiring' => 'lib/utils/assets/notifications/fridge_expired.png',
        _ => null,
      };
}
