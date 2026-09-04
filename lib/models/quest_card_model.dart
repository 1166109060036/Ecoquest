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
    title: 'Quest Name',
    subtitle: 'Place',
    category: QuestCardCategory.party,
    pointsReward: 0,
    dateLabel: 'Month D, Y',
    timeLabel: '00:00',
    capacityLabel: '00 / 00',
  ),
  QuestCardModel(
    title: 'Quest Name',
    subtitle: 'Quest Detail',
    category: QuestCardCategory.solo,
    pointsReward: 0,
    energyProgress: 0.0,
  ),
  QuestCardModel(
    title: 'Quest Name',
    subtitle: 'Place',
    category: QuestCardCategory.event,
    pointsReward: 0,
    dateLabel: 'Month D, Y',
    timeLabel: '00:00',
    capacityLabel: '00 / 00',
  ),
];
