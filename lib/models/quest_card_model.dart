// Model สำหรับแสดง Quest card ในหน้า Home/Explore
import 'achievement_model.dart';
import '../utils/quest_image.dart';

enum QuestCardCategory { solo, party, event }

class QuestCardModel {
  final String id; // _id ของ quest ฝั่ง backend — ใช้ตอนเรียก POST /api/quests/:id/complete
  final String title;
  final String subtitle; // "Place" สำหรับ party/event หรือ "Quest Detail" สำหรับ solo
  final QuestCardCategory category;
  final int pointsReward;
  final bool isDaily; // ⚠️ ไม่ใช้บังคับแล้ว — เควสทำซ้ำได้ไม่จำกัดต่อวัน (28 ก.ย. 2026)
  final int timesToday; // วันนี้ทำเควสนี้สำเร็จไปแล้วกี่ครั้ง (แค่โชว์ ไม่ได้ล็อกอะไร)
  // กด Start ไว้แล้วแต่ยังไม่กด Complete ที่หน้า Progress — ค้างได้ไม่จำกัดวัน
  final bool inProgress;
  final DateTime? startedAt; // เวลาที่กด Start — null ถ้ายังไม่ได้ start
  // quest ที่ต้องทำ action จริงในแอพก่อน ('fridge_check' = ต้องบันทึกของในตู้เย็น)
  // null = กดยืนยันเองได้เลย — ฝั่งแอพใช้ค่านี้ตัดสินว่ากด Start แล้วจะพาไปหน้าไหน
  final String? actionKey;
  // ---- เควสหลายวัน (Food Saver 3/7) — กด Complete ในหน้า Progress = เช็คอินวันละครั้ง ----
  final int durationDays; // 1 = เควสปกติ
  final int daysDone; // เช็คอินติดกันแล้วกี่วัน (มีค่าจริงเฉพาะข้อมูลจากหน้า Progress)
  final bool checkedInToday;

  bool get isMultiDay => durationDays > 1;

  // ---- ระบบตรวจสอบภารกิจ (28 ก.ย. 2026) ----
  // ต้องถ่ายรูปหลักฐานตอน Complete ไหม (ทุก solo ยกเว้น Check Food ที่ระบบตรวจจากตู้เย็นเอง)
  final bool requiresProof;
  // หลักฐานของเควสนี้ที่ส่งไปแล้วยังรอตรวจอยู่กี่ครั้ง
  final int pendingReview;
  // Daily Variety Combo (backend/utils/combo.js) — ตัวคูณแต้มถ้าทำเควสนี้ตอนนี้ (null = เควสนี้ไม่มีคอมโบ)
  // เควสใหม่ของวัน > 1 / ทำซ้ำ < 1
  final double? comboMultiplier;

  // ---- ใช้เฉพาะในหน้ารายละเอียด quest ----
  final String detail; // ข้อความอธิบายยาวในกล่อง "Quest Detail"
  final String? imageKey; // ชื่อไฟล์รูปปกในโฟลเดอร์ questimg (มีนามสกุลหรือไม่ก็ได้ ดู questCoverAsset)
  final int xpReward;
  // ค่าประมาณ kgCO2e ต่อการทำ 1 ครั้ง — null = วัดเป็น CO2 ไม่ได้ แสดง/นับเป็น 0 (ดู formatCo2e)
  final double? co2eEstimateKg;
  final String difficulty; // easy / medium / hard
  final String impact; // low / medium / high — ระดับผลกระทบต่อสิ่งแวดล้อม (ใช้คิดแต้มด้วย)
  final String questCategory; // food_waste / recycling / plastic / community / energy

  // ---- ใช้เฉพาะ party quest — quest เดี่ยวๆ นี้ยังไม่มี "ห้อง" (ต้องกดสร้างก่อน) ----
  // location/capacity เป็นแค่ค่า default ให้ฟอร์มสร้างห้องดึงไปเติม ไม่ได้ผูกกับห้องจริง
  final String location;
  final int capacity; // 0 = ไม่จำกัด
  final int minLevelToHost; // level ขั้นต่ำที่จะสร้างห้องจาก quest นี้ได้
  final int openPartyCount; // จำนวนห้องที่ยังเปิดรับสมาชิกอยู่ตอนนี้ — โชว์บนการ์ดเฉยๆ

  // path รูปปกจริง — null ถ้า quest นั้นยังไม่มีรูป
  String? get coverImageAsset =>
      questCoverAsset(imageKey);

  QuestCardModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.pointsReward,
    this.isDaily = false,
    this.timesToday = 0,
    this.inProgress = false,
    this.startedAt,
    this.actionKey,
    this.durationDays = 1,
    this.daysDone = 0,
    this.checkedInToday = false,
    this.requiresProof = false,
    this.pendingReview = 0,
    this.comboMultiplier,
    this.detail = '',
    this.imageKey,
    this.xpReward = 0,
    this.co2eEstimateKg,
    this.difficulty = '',
    this.impact = '',
    this.questCategory = '',
    this.location = '',
    this.capacity = 0,
    this.minLevelToHost = 1,
    this.openPartyCount = 0,
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
      timesToday: json['timesToday'] ?? 0,
      inProgress: json['inProgress'] ?? false,
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      actionKey: json['actionKey'],
      durationDays: json['durationDays'] ?? 1,
      daysDone: json['daysDone'] ?? 0,
      checkedInToday: json['checkedInToday'] ?? false,
      requiresProof: json['requiresProof'] ?? false,
      pendingReview: json['pendingReview'] ?? 0,
      comboMultiplier: (json['comboMultiplier'] as num?)?.toDouble(),
      detail: json['detail'] ?? '',
      imageKey: json['imageKey'],
      xpReward: json['xpReward'] ?? 0,
      // Mongo อาจส่งมาเป็น int ถ้าค่าเป็นจำนวนเต็มพอดี เลยต้องแปลงเป็น double เอง (null คงเป็น null)
      co2eEstimateKg: (json['co2eEstimateKg'] as num?)?.toDouble(),
      difficulty: json['difficulty'] ?? '',
      impact: json['impact'] ?? '',
      questCategory: json['category'] ?? '',
      location: json['location'] ?? '',
      capacity: json['capacity'] ?? 0,
      minLevelToHost: json['minLevelToHost'] ?? 1,
      openPartyCount: json['openPartyCount'] ?? 0,
    );
  }
}

// รางวัลที่ได้ตอนทำ quest สำเร็จ — มาจาก response ของ POST /api/quests/:id/complete
// (หรือ POST /api/party/complete ตอนหัวหน้าห้องกดจบอีเวนต์ ซึ่งใช้รูปแบบ response เดียวกัน)
class QuestReward {
  final int points;
  final int xp;
  // เหรียญที่เพิ่งปลดล็อกจากการทำ quest ครั้งนี้ (ปกติว่าง) — เอาไปเด้งแสดงความยินดี
  final List<UnlockedMedal> newAchievements;
  // ไม่ null เฉพาะตอนวันนี้ตรง milestone ของ Daily Streak (7/14/21/30) — เอาไปเด้ง celebrate
  final StreakMilestoneReward? streakMilestone;
  // ไม่ null เฉพาะเควสหลายวัน — ยังไม่ครบ (finished: false) = แค่เช็คอิน ไม่ได้แต้ม ห้ามเด้งฉลองรางวัล
  final QuestCheckIn? checkIn;
  // true = ส่งหลักฐานไปรอตรวจ ยังไม่ได้แต้ม (ระบบตรวจสอบภารกิจ) — ห้ามเด้งฉลองรางวัล รอแจ้งเตือน quest_approved
  final bool isPending;
  // Daily Variety Combo ของการทำครั้งนี้ (ถ้า pending = ตัวอย่าง ตัวจริงคิดตอนผ่าน) — null = เควสนี้ไม่มีคอมโบ
  final ComboInfo? combo;
  // Eco Bingo ครบแถว/การ์ดจากเควสนี้ (เฉพาะรางวัลทันทีแบบ Check Food) — null = ไม่มี
  final BingoReward? bingo;

  QuestReward({
    required this.points,
    required this.xp,
    this.newAchievements = const [],
    this.streakMilestone,
    this.checkIn,
    this.isPending = false,
    this.combo,
    this.bingo,
  });

  bool get isCheckInOnly => checkIn != null && !checkIn!.finished;

  // รับทั้งก้อน response มาเลย เพราะ earned กับ newAchievements อยู่คนละชั้นกัน
  factory QuestReward.fromResponse(Map<String, dynamic> json) {
    final earned = (json['earned'] ?? {}) as Map<String, dynamic>;
    final medals = (json['newAchievements'] ?? []) as List;
    final streakJson = json['streakMilestone'] as Map<String, dynamic>?;
    final checkInJson = json['checkIn'] as Map<String, dynamic>?;
    final comboJson = json['combo'] as Map<String, dynamic>?;
    final bingoJson = json['bingo'] as Map<String, dynamic>?;

    return QuestReward(
      isPending: json['status'] == 'pending',
      checkIn: checkInJson != null ? QuestCheckIn.fromJson(checkInJson) : null,
      points: earned['points'] ?? 0,
      xp: earned['xp'] ?? 0,
      newAchievements:
          medals.map((m) => UnlockedMedal.fromJson(m as Map<String, dynamic>)).toList(),
      streakMilestone: streakJson != null ? StreakMilestoneReward.fromJson(streakJson) : null,
      combo: comboJson != null ? ComboInfo.fromJson(comboJson) : null,
      bingo: bingoJson != null ? BingoReward.fromJson(bingoJson) : null,
    );
  }
}

// ---- Daily Variety Combo (backend/utils/combo.js) ----
// ทำเควสไม่ซ้ำกันในวันเดียวกัน = แต้มคูณเพิ่ม (×1.1, ×1.2 … เพดาน ×1.5) / ทำเควสเดิมซ้ำ = ลดลง (×0.75, ×0.5, ×0.25)
class ComboInfo {
  final double multiplier;
  final bool repeat;
  final int distinctToday;
  final double nextNewMultiplier;

  ComboInfo({required this.multiplier, this.repeat = false, this.distinctToday = 0, this.nextNewMultiplier = 1});

  factory ComboInfo.fromJson(Map<String, dynamic> json) => ComboInfo(
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1,
        repeat: json['repeat'] == true,
        distinctToday: json['distinctToday'] ?? 0,
        nextNewMultiplier: (json['nextNewMultiplier'] as num?)?.toDouble() ?? 1,
      );
}

// สรุปคอมโบวันนี้จาก GET /api/quests — แถบบนลิสต์เควส
class ComboSummary {
  final int distinctToday;
  final double nextNewMultiplier;
  final double maxMultiplier;

  ComboSummary({required this.distinctToday, required this.nextNewMultiplier, required this.maxMultiplier});

  factory ComboSummary.fromJson(Map<String, dynamic> json) => ComboSummary(
        distinctToday: json['distinctToday'] ?? 0,
        nextNewMultiplier: (json['nextNewMultiplier'] as num?)?.toDouble() ?? 1,
        maxMultiplier: (json['maxMultiplier'] as num?)?.toDouble() ?? 1.5,
      );
}

// Eco Bingo ครบแถว/การ์ด (backend/utils/bingo.js#settleCard)
class BingoReward {
  final int lines;
  final bool full;
  final int points;
  final int xp;

  BingoReward({required this.lines, required this.full, required this.points, required this.xp});

  factory BingoReward.fromJson(Map<String, dynamic> json) => BingoReward(
        lines: ((json['lines'] ?? []) as List).length,
        full: json['full'] == true,
        points: json['points'] ?? 0,
        xp: json['xp'] ?? 0,
      );
}

// ตัวคูณแบบอ่านง่าย: 1.1 -> "×1.1", 0.75 -> "×0.75", 1.5 -> "×1.5"
String formatMultiplier(double m) {
  final s = m.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '×$s';
}

// ผลการเช็คอินเควสหลายวัน — มาจาก POST /api/quests/:id/complete (ดู backend/routes/quests.js)
class QuestCheckIn {
  final int daysDone;
  final int durationDays;
  final bool restarted; // ลืมเช็คอินไปวันหนึ่ง = นับใหม่เป็นวันที่ 1
  final bool finished; // ครบวันสุดท้ายแล้ว ได้รางวัลเต็ม

  QuestCheckIn({
    required this.daysDone,
    required this.durationDays,
    required this.restarted,
    required this.finished,
  });

  factory QuestCheckIn.fromJson(Map<String, dynamic> json) {
    return QuestCheckIn(
      daysDone: json['daysDone'] ?? 0,
      durationDays: json['durationDays'] ?? 1,
      restarted: json['restarted'] ?? false,
      finished: json['finished'] ?? false,
    );
  }
}

// รางวัลที่ได้ตอนครบวัน milestone ของ Daily Streak — ดู backend/utils/streak.js เป็นเจ้าของสูตรจริง
class StreakMilestoneReward {
  final int day;
  final int points;
  final int xp;
  final String? itemType; // ไม่ null เฉพาะ milestone ที่แถมไอเทมพิเศษด้วย (ตอนนี้มีแค่วัน 30)

  StreakMilestoneReward({
    required this.day,
    required this.points,
    required this.xp,
    this.itemType,
  });

  factory StreakMilestoneReward.fromJson(Map<String, dynamic> json) {
    return StreakMilestoneReward(
      day: json['day'] ?? 0,
      points: json['points'] ?? 0,
      xp: json['xp'] ?? 0,
      itemType: json['itemType'],
    );
  }
}
