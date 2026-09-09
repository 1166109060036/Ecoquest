import 'package:flutter/material.dart';

// เหรียญจากระบบ Achievement — ข้อมูลจริงจาก GET /api/achievements
// backend ส่งมาทั้งเหรียญที่ปลดล็อกแล้วและยังไม่ปลดล็อก (พร้อมความคืบหน้า)
// เพื่อให้ผู้เล่นเห็นว่าเหลืออีกกี่ครั้งถึงจะได้
class AchievementMedalModel {
  final String medalType; // food_saver / recycling / plastic_reduction / energy_saver / community
  final String title;
  final String description;
  final String category;
  final int required;
  final int progress;
  final bool unlocked;
  final DateTime? unlockedAt;

  const AchievementMedalModel({
    required this.medalType,
    required this.title,
    required this.description,
    required this.category,
    required this.required,
    required this.progress,
    required this.unlocked,
    this.unlockedAt,
  });

  factory AchievementMedalModel.fromJson(Map<String, dynamic> json) {
    return AchievementMedalModel(
      medalType: json['medalType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      required: json['required'] ?? 1,
      progress: json['progress'] ?? 0,
      unlocked: json['unlocked'] ?? false,
      unlockedAt: DateTime.tryParse(json['unlockedAt']?.toString() ?? '')?.toLocal(),
    );
  }

  // ไอคอน/สีของเหรียญ อิงจากหมวดของ quest ที่ต้องทำ
  // (backend ส่งมาแค่ category ส่วนหน้าตาเป็นเรื่องของฝั่งแอพ)
  IconData get icon => switch (category) {
        'food_waste' => Icons.restaurant,
        'recycling' => Icons.recycling,
        'plastic' => Icons.local_drink,
        'energy' => Icons.bolt,
        'community' => Icons.groups,
        _ => Icons.emoji_events,
      };

  Color get color => switch (category) {
        'food_waste' => Colors.orange,
        'recycling' => Colors.teal,
        'plastic' => Colors.lightBlue,
        'energy' => Colors.amber,
        'community' => Colors.purple,
        _ => Colors.grey,
      };
}

// เหรียญที่เพิ่งปลดล็อกตอนทำ quest สำเร็จ — มาจาก response ของ POST /quests/:id/complete
class UnlockedMedal {
  final String medalType;
  final String title;
  final String description;

  UnlockedMedal({
    required this.medalType,
    required this.title,
    required this.description,
  });

  factory UnlockedMedal.fromJson(Map<String, dynamic> json) {
    return UnlockedMedal(
      medalType: json['medalType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
    );
  }
}
