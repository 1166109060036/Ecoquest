// โปรไฟล์สาธารณะของผู้เล่นคนอื่น — มาจาก GET /api/users/:id
// ใช้ model UserProgress/ProfileStats/AchievementMedalModel/QuestHistoryEntry เดิมซ้ำ
// เพราะ backend serialize เหมือน /auth/me กับ /quests/history เป๊ะๆ
import 'achievement_model.dart';
import 'profile_model.dart';
import 'quest_history_model.dart';

class PublicProfileModel {
  final String userId;
  final String displayName;
  final int level;
  final int points;
  final String rank;
  final UserProgress progress;
  final ProfileStats stats;
  final List<AchievementMedalModel> medals;
  final List<QuestHistoryEntry> history;

  PublicProfileModel({
    required this.userId,
    required this.displayName,
    required this.level,
    required this.points,
    required this.rank,
    required this.progress,
    required this.stats,
    required this.medals,
    required this.history,
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    final medalsJson = (json['medals'] ?? []) as List;
    final historyJson = (json['history'] ?? []) as List;

    return PublicProfileModel(
      userId: (user['id'] ?? '').toString(),
      displayName: user['displayName'] ?? 'Player',
      level: user['level'] ?? 1,
      points: user['points'] ?? 0,
      rank: user['rank'] ?? 'Bronze',
      progress: UserProgress.fromJson(json['progress'] ?? {}),
      stats: ProfileStats.fromJson(json['stats'] ?? {}),
      medals: medalsJson
          .map((m) => AchievementMedalModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      history: historyJson
          .map((h) => QuestHistoryEntry.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}
