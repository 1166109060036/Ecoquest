import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/achievement_model.dart';
import '../models/quest_card_model.dart';
import '../providers/achievement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/liquid_glass_dialog.dart';

// สิ่งที่ต้องทำ "หลังทำ quest สำเร็จ" — เหมือนกันทั้ง 4 ที่ที่ทำ quest ได้
// (หน้า Explore, แผ่น Explore ในหน้า Home, หน้า Fridge, และหัวหน้าห้องกดจบอีเวนต์ปาร์ตี้)
// รวมไว้ที่เดียวจะได้ไม่ต้องแก้ 4 จุดทุกครั้งที่เพิ่มอะไรตอนจบ quest
Future<void> handleQuestCompleted(BuildContext context, QuestReward reward) async {
  final authProvider = context.read<AuthProvider>();
  final achievementProvider = context.read<AchievementProvider>();
  final notificationProvider = context.read<NotificationProvider>();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Quest complete! +${reward.points} points, +${reward.xp} XP')),
  );

  await Future.wait([
    // points/XP เปลี่ยนแล้ว ต้องโหลดโปรไฟล์ใหม่ให้หน้า Profile/Home โชว์เลขล่าสุด
    authProvider.refreshProfile(),
    // ความคืบหน้าเหรียญขยับทุกครั้งที่ทำ quest ถึงจะยังไม่ปลดล็อกก็ตาม
    achievementProvider.loadAchievements(),
    // เควสสำเร็จ (และเหรียญที่เพิ่งปลดล็อกถ้ามี) มีแจ้งเตือนใหม่รอโหลดอยู่เสมอ
    notificationProvider.loadNotifications(),
  ]);

  if (!context.mounted || reward.newAchievements.isEmpty) return;

  HapticFeedback.mediumImpact();
  await _showMedalDialog(context, reward.newAchievements);
}

// เด้งแสดงความยินดีตอนได้เหรียญใหม่ — รองรับกรณีได้หลายเหรียญพร้อมกันด้วย
Future<void> _showMedalDialog(BuildContext context, List<UnlockedMedal> medals) {
  return LiquidGlassDialog.show<void>(
    context: context,
    icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
    title: medals.length > 1 ? 'New medals!' : 'New medal!',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final medal in medals)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medal.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
                Text(
                  medal.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const Text(
          'Check it in your Inventory.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
            shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
          ),
        ),
      ],
    ),
    actions: [
      LiquidGlassAction(label: 'Nice', color: Colors.green, onPressed: () => Navigator.pop(context)),
    ],
  );
}
