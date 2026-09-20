// โปรไฟล์สาธารณะของผู้เล่นคนอื่น — มาจาก GET /api/users/:id
// ใช้ model UserProgress/ProfileStats/AchievementMedalModel/QuestHistoryEntry เดิมซ้ำ
// เพราะ backend serialize เหมือน /auth/me กับ /quests/history เป๊ะๆ
import '../utils/constants.dart';
import 'achievement_model.dart';
import 'cosmetics_model.dart';
import 'profile_model.dart';
import 'quest_history_model.dart';

class PublicProfileModel {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final EquippedCosmetics cosmetics;
  final int level;
  final int points;
  final UserProgress progress;
  final StreakInfo streak;
  final ProfileStats stats;
  final List<AchievementMedalModel> medals;
  final List<QuestHistoryEntry> history;

  PublicProfileModel({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.cosmetics = const EquippedCosmetics(),
    required this.level,
    required this.points,
    required this.progress,
    required this.streak,
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
      avatarUrl: AppConstants.resolveUrl(user['avatarUrl']),
      cosmetics: EquippedCosmetics.fromJson(user['cosmetics']),
      level: user['level'] ?? 1,
      points: user['points'] ?? 0,
      progress: UserProgress.fromJson(json['progress'] ?? {}),
      streak: StreakInfo.fromJson(json['streak'] ?? {}),
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
