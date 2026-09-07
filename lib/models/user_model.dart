class UserModel {
  final String id;
  final String? email;
  final String displayName;
  final bool isGuest;

  // ---- ค่าระบบเกม ----
  // register/login/guest ไม่ได้ส่งค่าพวกนี้กลับมาด้วย จะได้ค่าจริงตอนเรียก GET /auth/me
  // เลยต้องมี default ไว้กัน null ตอน parse response ของ endpoint เก่าหรือ session ที่ cache ไว้ก่อนหน้า
  final int level;
  final int xp;
  final int points;
  final String rank;

  UserModel({
    required this.id,
    this.email,
    required this.displayName,
    required this.isGuest,
    this.level = 1,
    this.xp = 0,
    this.points = 0,
    this.rank = 'Bronze',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'],
      email: json['email'],
      displayName: json['displayName'] ?? 'Player',
      isGuest: json['isGuest'] ?? false,
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      points: json['points'] ?? 0,
      rank: json['rank'] ?? 'Bronze',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'isGuest': isGuest,
      'level': level,
      'xp': xp,
      'points': points,
      'rank': rank,
    };
  }
}
