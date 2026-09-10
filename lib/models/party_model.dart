// ปาร์ตี้ = กลุ่มคนที่เข้าร่วม party quest (อีเวนต์กลุ่ม) อันเดียวกัน
// ข้อมูลจริงจาก GET /api/party

class PartyMemberModel {
  final String userId;
  final String name;
  final int level;
  final String rank;
  final bool isLeader;
  final bool isMe; // ใช้ไฮไลต์แถวของตัวเองในรายชื่อ

  PartyMemberModel({
    required this.userId,
    required this.name,
    required this.level,
    required this.rank,
    required this.isLeader,
    required this.isMe,
  });

  factory PartyMemberModel.fromJson(Map<String, dynamic> json) {
    return PartyMemberModel(
      userId: (json['userId'] ?? '').toString(),
      name: json['displayName'] ?? 'Player',
      level: json['level'] ?? 1,
      rank: json['rank'] ?? 'Bronze',
      isLeader: json['isLeader'] ?? false,
      isMe: json['isMe'] ?? false,
    );
  }
}

// รายละเอียดอีเวนต์ที่ปาร์ตี้นี้กำลังจะไปทำ
class PartyQuestModel {
  final String id;
  final String title;
  final String description;
  final String detail;
  final String? imageKey;
  final String difficulty;
  final int scorePoints;
  final int xpReward;
  final double co2SavedKg;
  final DateTime? eventDate;
  final String location;
  final int capacity; // 0 = ไม่จำกัด
  final bool completed; // เราทำอีเวนต์นี้สำเร็จไปแล้วหรือยัง

  PartyQuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.detail,
    this.imageKey,
    required this.difficulty,
    required this.scorePoints,
    required this.xpReward,
    required this.co2SavedKg,
    this.eventDate,
    required this.location,
    required this.capacity,
    required this.completed,
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
      difficulty: json['difficulty'] ?? '',
      scorePoints: json['scorePoints'] ?? 0,
      xpReward: json['xpReward'] ?? 0,
      co2SavedKg: (json['co2SavedKg'] ?? 0).toDouble(),
      // เก็บใน DB เป็น UTC — แปลงเป็นเวลาเครื่องก่อนโชว์
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? '')?.toLocal(),
      location: json['location'] ?? '',
      capacity: json['capacity'] ?? 0,
      completed: json['completed'] ?? false,
    );
  }
}

class PartyModel {
  final PartyQuestModel quest;
  final List<PartyMemberModel> members;

  PartyModel({required this.quest, required this.members});

  // หัวหน้าปาร์ตี้ = คนแรกที่เข้าร่วม (backend เรียงมาให้แล้ว)
  PartyMemberModel? get leader {
    final leaders = members.where((m) => m.isLeader).toList();
    return leaders.isEmpty ? null : leaders.first;
  }

  List<PartyMemberModel> get others => members.where((m) => !m.isLeader).toList();

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    return PartyModel(
      quest: PartyQuestModel.fromJson(json['quest'] ?? {}),
      members: ((json['members'] ?? []) as List)
          .map((m) => PartyMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
