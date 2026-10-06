import 'package:flutter/material.dart';

// ขั้นของเหรียญ (Bronze / Silver / Gold) — backend/utils/achievements.js
class MedalTier {
  final String tier; // bronze / silver / gold
  final String label;
  final int required;
  final bool unlocked;
  final DateTime? unlockedAt;

  const MedalTier({
    required this.tier,
    required this.label,
    required this.required,
    required this.unlocked,
    this.unlockedAt,
  });

  factory MedalTier.fromJson(Map<String, dynamic> json) => MedalTier(
        tier: json['tier'] ?? 'bronze',
        label: json['label'] ?? '',
        required: json['required'] ?? 1,
        unlocked: json['unlocked'] == true,
        unlockedAt: DateTime.tryParse(json['unlockedAt']?.toString() ?? '')?.toLocal(),
      );
}

// ไอคอน/สีของเหรียญ อิงจากหมวดของ quest (backend ส่งมาแค่ category ส่วนหน้าตาเป็นเรื่องของฝั่งแอพ)
IconData medalCategoryIcon(String? category) => switch (category) {
      'food_waste' => Icons.restaurant,
      'recycling' => Icons.recycling,
      'plastic' => Icons.local_drink,
      'energy' => Icons.bolt,
      'community' => Icons.groups,
      _ => Icons.emoji_events,
    };

Color medalCategoryColor(String? category) => switch (category) {
      'food_waste' => Colors.orange,
      'recycling' => Colors.teal,
      'plastic' => Colors.lightBlue,
      'energy' => Colors.amber,
      'community' => Colors.purple,
      _ => Colors.grey,
    };

// สีประจำขั้นเหรียญ — ใช้ทั้งหน้า Eco Badge, โปรไฟล์ผู้เล่น และ dialog ฉลองตอนได้เหรียญ
Color medalTierColor(String? tier) => switch (tier) {
      'gold' => const Color(0xFFE0A526),
      'silver' => const Color(0xFF9AA6B2),
      'bronze' => const Color(0xFFB8733A),
      _ => Colors.grey,
    };

// เหรียญจากระบบ Achievement — ข้อมูลจริงจาก GET /api/achievements
// backend ส่งมาทั้งเหรียญที่ปลดล็อกแล้วและยังไม่ปลดล็อก (พร้อมความคืบหน้า) 1 แถวต่อหมวด
// แต่ละหมวดมี 3 ขั้น (Bronze/Silver/Gold) — required/progress = ของขั้นถัดไป
class AchievementMedalModel {
  final String medalType; // food_saver / recycling / plastic_reduction / energy_saver / community
  final String title;
  final String description;
  final String category;
  final int required;
  final int progress;
  final bool unlocked; // ได้ขั้น Bronze แล้ว
  final DateTime? unlockedAt;
  // ---- เหรียญหลายขั้น ----
  final int count; // จำนวนครั้งที่ทำเควสหมวดนี้จริง (ไม่ตัดเพดาน)
  final String? tier; // ขั้นสูงสุดที่ได้ (null = ยังไม่ได้)
  final String? tierLabel;
  final DateTime? tierUnlockedAt;
  final String? nextTier; // null = ครบทุกขั้นแล้ว
  final bool maxed;
  final List<MedalTier> tiers;

  const AchievementMedalModel({
    required this.medalType,
    required this.title,
    required this.description,
    required this.category,
    required this.required,
    required this.progress,
    required this.unlocked,
    this.unlockedAt,
    this.count = 0,
    this.tier,
    this.tierLabel,
    this.tierUnlockedAt,
    this.nextTier,
    this.maxed = false,
    this.tiers = const [],
  });

  factory AchievementMedalModel.fromJson(Map<String, dynamic> json) {
    final unlocked = json['unlocked'] ?? false;
    final tiersJson = (json['tiers'] as List?) ?? const [];
    return AchievementMedalModel(
      medalType: json['medalType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      required: json['required'] ?? 1,
      progress: json['progress'] ?? 0,
      unlocked: unlocked,
      unlockedAt: DateTime.tryParse(json['unlockedAt']?.toString() ?? '')?.toLocal(),
      count: json['count'] ?? json['progress'] ?? 0,
      // backend เก่าที่ยังไม่มีขั้น: ปลดล็อกแล้ว = Bronze
      tier: json['tier'] ?? (unlocked ? 'bronze' : null),
      tierLabel: json['tierLabel'] ?? (unlocked ? 'Bronze' : null),
      tierUnlockedAt: DateTime.tryParse(json['tierUnlockedAt']?.toString() ?? '')?.toLocal(),
      nextTier: json['nextTier'],
      maxed: json['maxed'] == true,
      tiers: tiersJson.map((t) => MedalTier.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }

  // จำนวนขั้นที่ได้แล้ว (0-3)
  int get tiersUnlocked => tiers.isEmpty ? (unlocked ? 1 : 0) : tiers.where((t) => t.unlocked).length;
  int get tiersTotal => tiers.isEmpty ? 1 : tiers.length;
  Color get tierColor => medalTierColor(tier);
  String? get nextTierLabel => nextTier == null
      ? null
      : tiers.firstWhere((t) => t.tier == nextTier,
              orElse: () => MedalTier(tier: nextTier!, label: nextTier!, required: required, unlocked: false))
          .label;

  IconData get icon => medalCategoryIcon(category);
  Color get color => medalCategoryColor(category);
}

// เหรียญที่เพิ่งปลดล็อกตอนทำ quest สำเร็จ — มาจาก response ของ POST /quests/:id/complete
class UnlockedMedal {
  final String medalType; // คีย์ขั้นนั้น เช่น food_saver / food_saver:silver
  final String title; // รวมชื่อขั้นแล้ว เช่น "Food Saver · Silver"
  final String description;
  final String? tier; // bronze / silver / gold (backend เก่าไม่มี = bronze)
  final String? category;

  UnlockedMedal({
    required this.medalType,
    required this.title,
    required this.description,
    this.tier,
    this.category,
  });

  factory UnlockedMedal.fromJson(Map<String, dynamic> json) {
    return UnlockedMedal(
      medalType: json['medalType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      tier: json['tier'] ?? 'bronze',
      category: json['category'],
    );
  }

  Color get tierColor => medalTierColor(tier);
  IconData get icon => medalCategoryIcon(category);
  Color get color => medalCategoryColor(category);
}
