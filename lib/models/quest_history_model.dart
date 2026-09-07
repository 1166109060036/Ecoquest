// ประวัติ quest ที่ทำสำเร็จ — มาจาก GET /api/quests/history
class QuestHistoryEntry {
  final String id;
  final String questTitle;
  final String? category; // food_waste / recycling / plastic / community (null ถ้า quest ถูกลบไปแล้ว)
  final int pointsEarned;
  final int xpEarned;
  final DateTime completedAt;

  QuestHistoryEntry({
    required this.id,
    required this.questTitle,
    this.category,
    required this.pointsEarned,
    required this.xpEarned,
    required this.completedAt,
  });

  factory QuestHistoryEntry.fromJson(Map<String, dynamic> json) {
    return QuestHistoryEntry(
      id: (json['id'] ?? '').toString(),
      questTitle: json['questTitle'] ?? 'Unknown quest',
      category: json['category'],
      pointsEarned: json['pointsEarned'] ?? 0,
      xpEarned: json['xpEarned'] ?? 0,
      // completedAt ควรมีเสมอ แต่กันไว้เผื่อข้อมูลเก่าที่ไม่มีค่านี้ ไม่ให้ทั้งลิสต์พัง
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
