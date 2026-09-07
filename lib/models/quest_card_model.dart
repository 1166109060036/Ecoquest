// Model สำหรับแสดง Quest card ในหน้า Home/Explore

enum QuestCardCategory { solo, party, event }

class QuestCardModel {
  final String id; // _id ของ quest ฝั่ง backend — ใช้ตอนเรียก POST /api/quests/:id/complete
  final String title;
  final String subtitle; // "Place" สำหรับ party/event หรือ "Quest Detail" สำหรับ solo
  final QuestCardCategory category;
  final int pointsReward;
  final String? dateLabel; // เช่น "Month D, Y"
  final String? timeLabel; // เช่น "00:00"
  final String? capacityLabel; // "00 / 00" คนเข้าร่วม — ใช้กับ party/event
  final bool isDaily; // ทำได้วันละครั้ง
  final bool completedToday; // วันนี้ทำไปแล้วหรือยัง (ใช้กับ quest ที่ isDaily)
  // quest ที่ต้องทำ action จริงในแอพก่อน ('fridge_check' = ต้องบันทึกของในตู้เย็น)
  // null = กดยืนยันเองได้เลย — ฝั่งแอพใช้ค่านี้ตัดสินว่ากด Start แล้วจะพาไปหน้าไหน
  final String? actionKey;

  QuestCardModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.pointsReward,
    this.dateLabel,
    this.timeLabel,
    this.capacityLabel,
    this.isDaily = false,
    this.completedToday = false,
    this.actionKey,
  });

  factory QuestCardModel.fromJson(Map<String, dynamic> json) {
    // backend ส่ง type มาเป็น 'solo' / 'party' เท่านั้น ส่วน 'event' เป็นการแบ่งฝั่ง UI
    final type = (json['type'] ?? 'solo').toString();
    final category = QuestCardCategory.values.firstWhere(
      (c) => c.name == type,
      orElse: () => QuestCardCategory.solo,
    );

    return QuestCardModel(
      id: json['id'] ?? json['_id'],
      title: json['title'] ?? '',
      subtitle: json['description'] ?? '',
      category: category,
      pointsReward: json['scorePoints'] ?? 0,
      isDaily: json['isDaily'] ?? false,
      completedToday: json['completedToday'] ?? false,
      actionKey: json['actionKey'],
    );
  }
}

// รางวัลที่ได้ตอนทำ quest สำเร็จ — มาจาก response ของ POST /api/quests/:id/complete
class QuestReward {
  final int points;
  final int xp;

  QuestReward({required this.points, required this.xp});

  factory QuestReward.fromJson(Map<String, dynamic> json) {
    return QuestReward(points: json['points'] ?? 0, xp: json['xp'] ?? 0);
  }
}
