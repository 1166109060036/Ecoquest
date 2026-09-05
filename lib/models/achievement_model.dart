import 'package:flutter/material.dart';

// Medal ที่ผู้เล่นปลดล็อกจากระบบ Achievement
// ตอนนี้ยังไม่ได้ต่อ backend Achievement API จริง ใช้ mock data ไปก่อน
class AchievementMedalModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int? quantity;

  const AchievementMedalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.quantity,
  });
}

// mock data — TODO: ดึงจาก GET /api/achievements จริงตอนมี endpoint
// อิงตาม medal ที่ออกแบบไว้ในเอกสารเกม: Food Saver, Recycling, Community, Plastic Reduction
final List<AchievementMedalModel> mockAchievementMedals = [
  AchievementMedalModel(
    id: 'food_saver',
    title: 'Food Saver Medal',
    description: 'Completed 10 Food Waste quests.',
    icon: Icons.restaurant,
    color: Colors.orange,
    quantity: 1,
  ),
  AchievementMedalModel(
    id: 'recycling',
    title: 'Recycling Medal',
    description: 'Completed 10 Recycling quests.',
    icon: Icons.recycling,
    color: Colors.teal,
    quantity: 1,
  ),
];
