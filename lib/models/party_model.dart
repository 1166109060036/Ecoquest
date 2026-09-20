// ปาร์ตี้ = "ห้อง" ที่ผู้เล่นกดสร้างขึ้นจาก party quest ที่มีอยู่แล้ว (เหมือนห้องในเกม)
// ข้อมูลจริงจาก GET /api/party (ห้องของฉัน) และ GET /api/party/rooms (ลิสต์ห้องให้เข้าร่วม)
import '../utils/constants.dart';
import 'cosmetics_model.dart';
import 'quest_card_model.dart' show QuestReward;

// ผลตอบกลับตอนหัวหน้ากดจบอีเวนต์ — ต้องคืนทั้งรางวัลของหัวหน้าเอง (ไปเด้ง handleQuestCompleted
// แบบเดียวกับ quest ทั่วไป) และห้องล่าสุด (สถานะเปลี่ยนเป็น completed แล้ว) ไปอัปเดต provider
class PartyCompleteReward {
  final QuestReward reward;
  final int awardedCount; // กี่คนในห้องที่ได้คะแนนรอบนี้ (คนที่ทำเควสนี้ไปแล้ววันนี้จะไม่นับซ้ำ)
  final PartyModel party;

  PartyCompleteReward({
    required this.reward,
    required this.awardedCount,
    required this.party,
  });
}

class PartyMemberModel {
  final String userId;
  final String name;
  final String? avatarUrl; // null = ยังไม่ได้ตั้งรูปโปรไฟล์ (โชว์ไอคอนคนแทน)
  final EquippedCosmetics cosmetics;
  final int level;
  final bool isLeader;
  final bool isMe; // ใช้ไฮไลต์แถวของตัวเองในรายชื่อ

  PartyMemberModel({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.cosmetics = const EquippedCosmetics(),
    required this.level,
    required this.isLeader,
    required this.isMe,
  });

  factory PartyMemberModel.fromJson(Map<String, dynamic> json) {
    return PartyMemberModel(
      userId: (json['userId'] ?? '').toString(),
      name: json['displayName'] ?? 'Player',
      avatarUrl: AppConstants.resolveUrl(json['avatarUrl']),
      cosmetics: EquippedCosmetics.fromJson(json['cosmetics']),
      level: json['level'] ?? 1,
      isLeader: json['isLeader'] ?? false,
      isMe: json['isMe'] ?? false,
    );
  }
}

// quest template ที่ห้องนี้สร้างมาจาก — รายละเอียดรางวัล/หมวดหมู่ ไม่มีวันเวลา/สถานที่แล้ว
// (ย้ายไปอยู่ที่ตัวห้อง PartyModel เพราะแต่ละห้องนัดคนละเวลากันได้ ถึงจะสร้างจาก quest เดียวกัน)
class PartyQuestModel {
  final String id;
  final String title;
  final String description;
  final String detail;
  final String? imageKey;
  final String category; // food_waste / recycling / plastic / community / energy — ใช้เลือกไอคอน placeholder ตอนยังไม่มีรูปปก
  final String difficulty;
  final String impact;
  final int scorePoints;
  final int xpReward;
  final double co2SavedKg;

  PartyQuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.detail,
    this.imageKey,
    this.category = '',
    required this.difficulty,
    this.impact = '',
    required this.scorePoints,
    required this.xpReward,
    required this.co2SavedKg,
  });

  String? get coverImageAsset =>
      imageKey == null ? null : 'lib/utils/assets/questimg/$imageKey.png';

  factory PartyQuestModel.fromJson(Map<String, dynamic> json) {
    return PartyQuestModel(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      detail: json['detail'] ?? '',
      imageKey: json['imageKey'],
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? '',
      impact: json['impact'] ?? '',
      scorePoints: json['scorePoints'] ?? 0,
      xpReward: json['xpReward'] ?? 0,
      co2SavedKg: (json['co2SavedKg'] ?? 0).toDouble(),
    );
  }
}

// ห้องที่ฉันอยู่ตอนนี้ (จาก GET /api/party) — เข้าร่วมได้ทีละห้องตามดีไซน์
class PartyModel {
  final String id;
  final String name; // ชื่อห้องที่ผู้สร้างตั้งเอง
  final String status; // 'open' | 'started' | 'completed'
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime eventDate;
  final String location;
  final int capacity; // ห้องใหม่บังคับ >= 2 เสมอ — 0 เหลือแค่ห้องเก่าก่อนหน้านี้
  final bool isLeader; // ฉันเป็นหัวหน้าห้องนี้ไหม — ใช้ตัดสินใจโชว์ปุ่ม Start/Complete
  final int memberCount; // จาก backend ตรงๆ (แทนที่จะนับจาก members.length เอง)
  final int requiredMembers; // ต้องมีกี่คนถึงจะกด Start ได้ (ดู utils/partyGate.js#requiredMembers)
  // canStart/canComplete มาจาก backend ตรงๆ — ใช้แค่โชว์/ซ่อนปุ่มเฉยๆ backend ยังเช็คซ้ำทุก request จริง
  // อยู่ดี ไม่ได้เชื่อค่าพวกนี้ตอนกด action (เผื่อเวลาเครื่อง client ไม่ตรง หรือ payload เก่าค้าง cache)
  final bool canStart;
  final String? startBlockedReason;
  final bool canComplete;
  final String? completeBlockedReason;
  final PartyQuestModel quest;
  final List<PartyMemberModel> members;

  PartyModel({
    required this.id,
    required this.name,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.eventDate,
    required this.location,
    required this.capacity,
    required this.isLeader,
    required this.memberCount,
    required this.requiredMembers,
    required this.canStart,
    this.startBlockedReason,
    required this.canComplete,
    this.completeBlockedReason,
    required this.quest,
    required this.members,
  });

  bool get isOpen => status == 'open';
  bool get isStarted => status == 'started';
  bool get isCompleted => status == 'completed';
  bool get isFull => memberCount >= requiredMembers;

  // ⚠️ ต้องตรงกับ START_TO_COMPLETE_MS ใน backend/utils/partyGate.js เสมอ — ใช้แค่คำนวณนับถอยหลัง/
  // เปิด-ปิดปุ่มแบบ live ฝั่งแอพเท่านั้น (canStart/canComplete จาก backend คือค่าที่เชื่อถือได้จริง
  // ทุก request ยังถูกเช็คซ้ำที่ server เสมอ ไม่ได้เชื่อค่าที่คำนวณสดตรงนี้)
  static const _startToCompleteDuration = Duration(minutes: 15);

  // คำนวณสดด้วย `now` ที่ส่งเข้ามา (ไม่ใช้ DateTime.now() ตรงๆ ในนี้ เพื่อให้ทดสอบ/นับถอยหลังจาก
  // Timer.periodic เดียวกันได้ ไม่ต้อง query เวลาซ้ำหลายจุด)
  bool isReadyToStartAt(DateTime now) =>
      isOpen && !now.isBefore(eventDate) && memberCount >= requiredMembers;

  // เวลาที่เหลือก่อนจะกด Complete ได้ — null ถ้ายังไม่ได้ start หรือ start ไปนานพอแล้ว
  Duration? completeCountdownAt(DateTime now) {
    if (!isStarted || startedAt == null) return null;
    final readyAt = startedAt!.add(_startToCompleteDuration);
    if (!now.isBefore(readyAt)) return null;
    return readyAt.difference(now);
  }

  bool isReadyToCompleteAt(DateTime now) => isStarted && completeCountdownAt(now) == null;

  // หัวหน้าปาร์ตี้ (backend เรียงมาให้ขึ้นก่อนแล้ว)
  PartyMemberModel? get leader {
    final leaders = members.where((m) => m.isLeader).toList();
    return leaders.isEmpty ? null : leaders.first;
  }

  List<PartyMemberModel> get others => members.where((m) => !m.isLeader).toList();

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    return PartyModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      status: json['status'] ?? 'open',
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '')?.toLocal(),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? '')?.toLocal(),
      // เก็บใน DB เป็น UTC — แปลงเป็นเวลาเครื่องก่อนโชว์
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      location: json['location'] ?? '',
      capacity: json['capacity'] ?? 0,
      isLeader: json['isLeader'] ?? false,
      memberCount: json['memberCount'] ?? 0,
      requiredMembers: json['requiredMembers'] ?? 2,
      canStart: json['canStart'] ?? false,
      startBlockedReason: json['startBlockedReason'],
      canComplete: json['canComplete'] ?? false,
      completeBlockedReason: json['completeBlockedReason'],
      quest: PartyQuestModel.fromJson(json['quest'] ?? {}),
      members: ((json['members'] ?? []) as List)
          .map((m) => PartyMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

// รายการย่อของ quest ที่แสดงในลิสต์ห้อง — ไม่ต้องลากรายละเอียดยาวๆ (detail) มาด้วย
class PartyRoomQuestModel {
  final String id;
  final String title;
  final String? imageKey;
  final String category;
  final String difficulty;
  final int scorePoints;
  final int xpReward;

  PartyRoomQuestModel({
    required this.id,
    required this.title,
    this.imageKey,
    this.category = '',
    this.difficulty = '',
    required this.scorePoints,
    required this.xpReward,
  });

  String? get coverImageAsset =>
      imageKey == null ? null : 'lib/utils/assets/questimg/$imageKey.png';

  factory PartyRoomQuestModel.fromJson(Map<String, dynamic> json) {
    return PartyRoomQuestModel(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      imageKey: json['imageKey'],
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? '',
      scorePoints: json['scorePoints'] ?? 0,
      xpReward: json['xpReward'] ?? 0,
    );
  }
}

// ห้องที่โผล่ในลิสต์ให้เลือกเข้าร่วม (จาก GET /api/party/rooms) — ยังไม่ใช่ห้องของฉัน
class PartyRoomModel {
  final String id;
  final String name;
  final DateTime eventDate;
  final String location;
  final int capacity;
  final int memberCount;
  final bool isFull;
  final PartyRoomQuestModel quest;

  PartyRoomModel({
    required this.id,
    required this.name,
    required this.eventDate,
    required this.location,
    required this.capacity,
    required this.memberCount,
    required this.isFull,
    required this.quest,
  });

  factory PartyRoomModel.fromJson(Map<String, dynamic> json) {
    return PartyRoomModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      location: json['location'] ?? '',
      capacity: json['capacity'] ?? 0,
      memberCount: json['memberCount'] ?? 0,
      isFull: json['isFull'] ?? false,
      quest: PartyRoomQuestModel.fromJson(json['quest'] ?? {}),
    );
  }
}
