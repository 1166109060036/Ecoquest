// Model สำหรับแสดง Quest card ในหน้า Home/Explore
// ตอนนี้ยังไม่ได้ต่อ backend Quest API จริง ใช้ mock data ไปก่อน

enum QuestCardCategory { solo, party, event }

class QuestCardModel {
  final String title;
  final String subtitle; // "Place" สำหรับ party/event หรือ "Quest Detail" สำหรับ solo
  final QuestCardCategory category;
  final int pointsReward;
  final String? dateLabel; // เช่น "Month D, Y"
  final String? timeLabel; // เช่น "00:00"
  final String? capacityLabel; // "00 / 00" คนเข้าร่วม — ใช้กับ party/event
  final double? energyProgress; // 0.0–1.0 ใช้กับ solo quest แทนแถบพลังงาน

  QuestCardModel({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.pointsReward,
    this.dateLabel,
    this.timeLabel,
    this.capacityLabel,
    this.energyProgress,
  });
}

// mock data ไว้ก่อน — TODO: ดึงจาก GET /api/quests จริงตอนมี endpoint
final List<QuestCardModel> mockQuestCards = [
  QuestCardModel(
    title: 'Community Cleanup',
    subtitle: 'Riverside Park',
    category: QuestCardCategory.party,
    pointsReward: 30,
    dateLabel: 'Sep 12, 2026',
    timeLabel: '09:00',
    capacityLabel: '04 / 10',
  ),
  QuestCardModel(
    title: 'Finish Your Meal',
    subtitle: 'Food Waste Quest',
    category: QuestCardCategory.solo,
    pointsReward: 10,
    energyProgress: 1.0,
  ),
  QuestCardModel(
    title: 'Tree Planting Day',
    subtitle: 'Ebetsu City Park',
    category: QuestCardCategory.event,
    pointsReward: 30,
    dateLabel: 'Sep 20, 2026',
    timeLabel: '10:00',
    capacityLabel: '12 / 30',
  ),
  QuestCardModel(
    title: 'Use a Refillable Bottle',
    subtitle: 'Plastic Reduction Quest',
    category: QuestCardCategory.solo,
    pointsReward: 15,
    energyProgress: 0.6,
  ),
  QuestCardModel(
    title: 'Sort Your Waste',
    subtitle: 'Recycling Quest',
    category: QuestCardCategory.solo,
    pointsReward: 10,
    energyProgress: 0.3,
  ),
  QuestCardModel(
    title: 'Neighborhood Recycling Drive',
    subtitle: 'Community Center',
    category: QuestCardCategory.party,
    pointsReward: 25,
    dateLabel: 'Sep 15, 2026',
    timeLabel: '13:00',
    capacityLabel: '07 / 15',
  ),
  QuestCardModel(
    title: 'Check Food & Expiration Dates',
    subtitle: 'Mini Quest — Fridge Check',
    category: QuestCardCategory.solo,
    pointsReward: 5,
    energyProgress: 0.8,
  ),
  QuestCardModel(
    title: 'Ebetsu Eco Festival',
    subtitle: 'City Hall Square',
    category: QuestCardCategory.event,
    pointsReward: 30,
    dateLabel: 'Sep 28, 2026',
    timeLabel: '11:00',
    capacityLabel: '20 / 50',
  ),
];
