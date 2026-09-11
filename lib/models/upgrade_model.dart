import 'package:flutter/material.dart';

// upgrade ที่ซื้อได้ในการ์ด "Upgrade your Ability" — ข้อมูลจริงจาก GET /api/upgrades
// backend ส่งมาแค่ upgradeType + title/description/level/maxLevel/nextCost
// ส่วนไอคอน/สีเป็นเรื่องของฝั่งแอพ (แนวเดียวกับ InventoryItemModel.icon)
class UpgradeModel {
  final String upgradeType;
  final String title;
  final String description;
  final int level;
  final int maxLevel;
  final int? nextCost; // null = เต็มระดับแล้ว ซื้อต่อไม่ได้

  const UpgradeModel({
    required this.upgradeType,
    required this.title,
    required this.description,
    required this.level,
    required this.maxLevel,
    this.nextCost,
  });

  factory UpgradeModel.fromJson(Map<String, dynamic> json) {
    return UpgradeModel(
      upgradeType: json['upgradeType'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      level: json['level'] ?? 0,
      maxLevel: json['maxLevel'] ?? 0,
      nextCost: json['nextCost'],
    );
  }

  bool get isMaxed => nextCost == null;

  IconData get icon => switch (upgradeType) {
        'point_booster' => Icons.trending_up,
        'xp_booster' => Icons.bolt,
        'rank_booster' => Icons.military_tech,
        'party_bonus' => Icons.star,
        'quest_unlock' => Icons.lock_open,
        _ => Icons.auto_awesome,
      };

  Color get color => switch (upgradeType) {
        'point_booster' => Colors.greenAccent,
        'xp_booster' => Colors.amberAccent,
        'rank_booster' => Colors.orangeAccent,
        'party_bonus' => Colors.purpleAccent,
        'quest_unlock' => Colors.lightBlueAccent,
        _ => Colors.white,
      };
}
