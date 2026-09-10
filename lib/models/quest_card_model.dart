// Model สำหรับแสดง Quest card ในหน้า Home/Explore
import 'achievement_model.dart';

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

  // ---- ใช้เฉพาะในหน้ารายละเอียด quest ----
  final String detail; // ข้อความอธิบายยาวในกล่อง "Quest Detail"
  final String? imageKey; // ชื่อไฟล์รูปปก (ไม่รวมนามสกุล) ในโฟลเดอร์ questimg
  final int xpReward;
  final double co2SavedKg;
  final String difficulty; // easy / medium / hard
  final String impact; // low / medium / high
  final String questCategory; // food_waste / recycling / plastic / community / energy

  // ---- ใช้เฉพาะ party quest (อีเวนต์กลุ่ม) ----
  final int capacity; // 0 = ไม่จำกัด
  final int joinedCount;
  final bool hasJoined; // เราเข้าร่วมอีเวนต์นี้ไปแล้วหรือยัง

  bool get isFull => capacity > 0 && joinedCount >= capacity;

  // path รูปปกจริง — null ถ้า quest นั้นยังไม่มีรูป
  String? get coverImageAsset =>
      imageKey == null ? null : 'lib/utils/assets/questimg/$imageKey.png';

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
    this.detail = '',
    this.imageKey,
    this.xpReward = 0,
    this.co2SavedKg = 0,
    this.difficulty = '',
    this.impact = '',
    this.questCategory = '',
    this.capacity = 0,
    this.joinedCount = 0,
    this.hasJoined = false,
  });

  factory QuestCardModel.fromJson(Map<String, dynamic> json) {
    // backend ส่ง type มาเป็น 'solo' / 'party' เท่านั้น ส่วน 'event' เป็นการแบ่งฝั่ง UI
    final type = (json['type'] ?? 'solo').toString();
    final category = QuestCardCategory.values.firstWhere(
      (c) => c.name == type,
      orElse: () => QuestCardCategory.solo,
    );

    // party quest ส่ง eventDate มาเป็น UTC — แปลงเป็นเวลาเครื่องแล้วทำเป็น label ให้การ์ดใช้เลย
    final eventDate = DateTime.tryParse(json['eventDate']?.toString() ?? '')?.toLocal();
    final capacity = json['capacity'] ?? 0;
    final joinedCount = json['joinedCount'] ?? 0;

    return QuestCardModel(
      id: json['id'] ?? json['_id'],
      title: json['title'] ?? '',
      subtitle: json['description'] ?? '',
      category: category,
      pointsReward: json['scorePoints'] ?? 0,
      dateLabel: eventDate == null ? null : _shortDate(eventDate),
      timeLabel: eventDate == null ? null : _shortTime(eventDate),
      capacityLabel: capacity > 0
          ? '${_pad(joinedCount)} / ${_pad(capacity)}'
          : (joinedCount > 0 ? '$joinedCount joined' : null),
      capacity: capacity,
      joinedCount: joinedCount,
      hasJoined: json['hasJoined'] ?? false,
      isDaily: json['isDaily'] ?? false,
      completedToday: json['completedToday'] ?? false,
      actionKey: json['actionKey'],
      detail: json['detail'] ?? '',
      imageKey: json['imageKey'],
      xpReward: json['xpReward'] ?? 0,
      // Mongo อาจส่งมาเป็น int ถ้าค่าเป็นจำนวนเต็มพอดี เลยต้องแปลงเป็น double เอง
      co2SavedKg: (json['co2SavedKg'] ?? 0).toDouble(),
      difficulty: json['difficulty'] ?? '',
      impact: json['impact'] ?? '',
      questCategory: json['category'] ?? '',
    );
  }
}

// รางวัลที่ได้ตอนทำ quest สำเร็จ — มาจาก response ของ POST /api/quests/:id/complete
class QuestReward {
  final int points;
  final int xp;
  // เหรียญที่เพิ่งปลดล็อกจากการทำ quest ครั้งนี้ (ปกติว่าง) — เอาไปเด้งแสดงความยินดี
  final List<UnlockedMedal> newAchievements;

  QuestReward({
    required this.points,
    required this.xp,
    this.newAchievements = const [],
  });

  // รับทั้งก้อน response มาเลย เพราะ earned กับ newAchievements อยู่คนละชั้นกัน
  factory QuestReward.fromResponse(Map<String, dynamic> json) {
    final earned = (json['earned'] ?? {}) as Map<String, dynamic>;
    final medals = (json['newAchievements'] ?? []) as List;

    return QuestReward(
      points: earned['points'] ?? 0,
      xp: earned['xp'] ?? 0,
      newAchievements:
          medals.map((m) => UnlockedMedal.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

// ---- helper สำหรับทำ label ของ party quest (ไม่ได้ลง intl เลยจัดรูปแบบเอง) ----
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _pad(int n) => n.toString().padLeft(2, '0');
String _shortDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
String _shortTime(DateTime d) => '${_pad(d.hour)}:${_pad(d.minute)}';
