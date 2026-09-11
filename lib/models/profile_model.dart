// Model สำหรับข้อมูลที่แสดงในหน้า Profile — ได้มาจาก GET /api/auth/me
import 'user_model.dart';

// ความคืบหน้าของ level และ rank — backend คำนวณมาให้หมดแล้ว ฝั่งแอพแค่เอาไปวาด progress bar
class UserProgress {
  final int level;
  final int xp;
  final int xpIntoLevel; // XP ที่ทำได้แล้วภายใน level ปัจจุบัน
  final int xpForNextLevel; // XP ทั้งหมดที่ต้องใช้เพื่อขึ้น level ถัดไป
  final String rankTier;
  final int seasonXp; // XP ที่ได้ใน season ปัจจุบัน (ตัวที่ใช้คิด rank)
  final int rankXpIntoTier;
  final int? rankXpForNextTier; // null = อยู่ tier สูงสุดแล้ว

  UserProgress({
    required this.level,
    required this.xp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.rankTier,
    required this.seasonXp,
    required this.rankXpIntoTier,
    this.rankXpForNextTier,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      xpIntoLevel: json['xpIntoLevel'] ?? 0,
      xpForNextLevel: json['xpForNextLevel'] ?? 0,
      rankTier: json['rankTier'] ?? 'Bronze',
      seasonXp: json['seasonXp'] ?? 0,
      rankXpIntoTier: json['rankXpIntoTier'] ?? 0,
      rankXpForNextTier: json['rankXpForNextTier'],
    );
  }
}

// ก้อนข้อมูลทั้งหมดที่ GET /api/auth/me ส่งกลับมา
class ProfileData {
  final UserModel user;
  final UserProgress progress;
  final ProfileStats stats;

  ProfileData({required this.user, required this.progress, required this.stats});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      user: UserModel.fromJson(json['user']),
      progress: UserProgress.fromJson(json['progress'] ?? {}),
      stats: ProfileStats.fromJson(json['stats'] ?? {}),
    );
  }
}

class ProfileStats {
  final int questCompleted;
  final int questTotal;
  final double co2SavedKg;
  final int partiesJoined;

  ProfileStats({
    required this.questCompleted,
    required this.questTotal,
    required this.co2SavedKg,
    required this.partiesJoined,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      questCompleted: json['questCompleted'] ?? 0,
      questTotal: json['questTotal'] ?? 0,
      co2SavedKg: (json['co2SavedKg'] ?? 0).toDouble(),
      partiesJoined: json['partiesJoined'] ?? 0,
    );
  }
}
