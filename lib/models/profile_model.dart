// Model สำหรับข้อมูลที่แสดงในหน้า Profile — ได้มาจาก GET /api/auth/me
import 'user_model.dart';

// ความคืบหน้าของ level — backend คำนวณมาให้หมดแล้ว ฝั่งแอพแค่เอาไปวาด progress bar
class UserProgress {
  final int level;
  final int xp;
  final int xpIntoLevel; // XP ที่ทำได้แล้วภายใน level ปัจจุบัน
  final int xpForNextLevel; // XP ทั้งหมดที่ต้องใช้เพื่อขึ้น level ถัดไป

  UserProgress({
    required this.level,
    required this.xp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      xpIntoLevel: json['xpIntoLevel'] ?? 0,
      xpForNextLevel: json['xpForNextLevel'] ?? 0,
    );
  }
}

// รางวัลของ milestone หนึ่งวัน — ตัวเลขจริงมาจาก backend/utils/streak.js เท่านั้น (ฝั่งนี้แค่โชว์ preview
// ไม่ hardcode ซ้ำ)
class StreakRewardPreview {
  final int points;
  final int xp;
  final String? itemType; // ไม่ null เฉพาะ milestone ที่แถมไอเทมพิเศษด้วย

  StreakRewardPreview({required this.points, required this.xp, this.itemType});

  factory StreakRewardPreview.fromJson(Map<String, dynamic> json) {
    return StreakRewardPreview(
      points: json['points'] ?? 0,
      xp: json['xp'] ?? 0,
      itemType: json['itemType'],
    );
  }
}

// Daily Streak — จำนวนวันติดต่อกันที่ทำเควสสำเร็จอย่างน้อย 1 อัน รอบละ 30 วัน มีของรางวัลที่
// วัน 7/14/21/30 (ดู backend/utils/streak.js เป็นเจ้าของสูตรจริง ฝั่งนี้แค่โชว์ผลลัพธ์)
class StreakInfo {
  final int count;
  final int cycleLength;
  final List<int> milestones;
  final Map<int, StreakRewardPreview> rewards;

  StreakInfo({
    required this.count,
    required this.cycleLength,
    required this.milestones,
    required this.rewards,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) {
    final rewardsJson = (json['rewards'] ?? {}) as Map<String, dynamic>;
    return StreakInfo(
      count: json['count'] ?? 0,
      cycleLength: json['cycleLength'] ?? 30,
      milestones: ((json['milestones'] ?? []) as List).map((m) => m as int).toList()..sort(),
      rewards: rewardsJson.map(
        (day, reward) => MapEntry(int.parse(day), StreakRewardPreview.fromJson(reward as Map<String, dynamic>)),
      ),
    );
  }

  // milestone ถัดไปที่ยังไม่ถึง — null ถ้า count ครอบคลุมทุก milestone แล้ว (ไม่ควรเกิดจริงเพราะครบ
  // รอบสุดท้าย (cycleLength) แล้ว backend จะรีเซ็ท count กลับเป็น 0 ให้เองเสมอ)
  int? get nextMilestone => milestones.cast<int?>().firstWhere((m) => m! > count, orElse: () => null);

  StreakRewardPreview? get nextReward => nextMilestone != null ? rewards[nextMilestone] : null;
}

// ก้อนข้อมูลทั้งหมดที่ GET /api/auth/me ส่งกลับมา
class ProfileData {
  final UserModel user;
  final UserProgress progress;
  final StreakInfo streak;
  final ProfileStats stats;

  ProfileData({
    required this.user,
    required this.progress,
    required this.streak,
    required this.stats,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      user: UserModel.fromJson(json['user']),
      progress: UserProgress.fromJson(json['progress'] ?? {}),
      streak: StreakInfo.fromJson(json['streak'] ?? {}),
      stats: ProfileStats.fromJson(json['stats'] ?? {}),
    );
  }
}

class ProfileStats {
  // จำนวนครั้งที่ทำเควสสำเร็จทั้งหมด (นับรวมเควสซ้ำ เช่นเควสรายวันที่ทำคนละวันด้วย ไม่ dedupe
  // ตาม questId) — ไม่มี "/ ทั้งหมด" แล้วเพราะเควสรายวันทำซ้ำได้ไม่จำกัด ไม่มี "ทั้งหมด" ที่ตายตัวจริงๆ
  final int questCompleted;
  final double co2SavedKg;
  final int partiesJoined;

  ProfileStats({
    required this.questCompleted,
    required this.co2SavedKg,
    required this.partiesJoined,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      questCompleted: json['questCompleted'] ?? 0,
      co2SavedKg: (json['co2SavedKg'] ?? 0).toDouble(),
      partiesJoined: json['partiesJoined'] ?? 0,
    );
  }
}
