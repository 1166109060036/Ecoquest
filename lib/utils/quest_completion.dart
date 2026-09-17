import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/achievement_model.dart';
import '../models/quest_card_model.dart';
import '../providers/achievement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/sound_service.dart';
import '../widgets/bubble_toast.dart';
import '../widgets/liquid_glass_dialog.dart';
import '../widgets/particle_burst.dart';

// สิ่งที่ต้องทำ "หลังทำ quest สำเร็จ" — เหมือนกันทั้ง 4 ที่ที่ทำ quest ได้
// (หน้า Explore, แผ่น Explore ในหน้า Home, หน้า Fridge, และหัวหน้าห้องกดจบอีเวนต์ปาร์ตี้)
// รวมไว้ที่เดียวจะได้ไม่ต้องแก้ 4 จุดทุกครั้งที่เพิ่มอะไรตอนจบ quest
Future<void> handleQuestCompleted(BuildContext context, QuestReward reward) async {
  final authProvider = context.read<AuthProvider>();
  final achievementProvider = context.read<AchievementProvider>();
  final notificationProvider = context.read<NotificationProvider>();

  // ⚠️ ต้องอ่าน level ปัจจุบันไว้ "ก่อน" เรียก refreshProfile() เท่านั้น เพราะ refreshProfile()
  // แทนที่ _profile ทั้งก้อนด้วยของใหม่ — ถ้าอ่านหลัง await จะเจอค่าใหม่ทั้งคู่ เทียบแล้วไม่มีทางเห็นว่า
  // เลเวลอัพจริงๆ
  final levelBefore = authProvider.profile?.progress.level ?? 1;

  showBubbleToast(context, 'Quest complete! +${reward.points} points, +${reward.xp} XP');
  showParticleBurst(context, color: Colors.amber);
  SoundService.instance.playQuestSuccess();

  await Future.wait([
    // points/XP เปลี่ยนแล้ว ต้องโหลดโปรไฟล์ใหม่ให้หน้า Profile/Home โชว์เลขล่าสุด
    authProvider.refreshProfile(),
    // ความคืบหน้าเหรียญขยับทุกครั้งที่ทำ quest ถึงจะยังไม่ปลดล็อกก็ตาม
    achievementProvider.loadAchievements(),
    // เควสสำเร็จ (และเหรียญที่เพิ่งปลดล็อกถ้ามี) มีแจ้งเตือนใหม่รอโหลดอยู่เสมอ
    notificationProvider.loadNotifications(),
  ]);

  if (!context.mounted) return;

  // เหรียญก่อน แล้วค่อยเลเวลอัพ ถ้าเกิดพร้อมกันทั้งคู่ (เช่น ทำเควสยากได้คะแนนเยอะจนเลเวลขึ้นพอดี)
  if (reward.newAchievements.isNotEmpty) {
    HapticFeedback.mediumImpact();
    await _showMedalDialog(context, reward.newAchievements);
    if (!context.mounted) return;
  }

  final levelAfter = authProvider.profile?.progress.level ?? levelBefore;
  if (levelAfter > levelBefore) {
    HapticFeedback.heavyImpact();
    await _showLevelUpDialog(context, levelAfter);
    if (!context.mounted) return;
  }

  // Daily Streak milestone (วัน 7/14/21/30) — มาหลังสุด ให้ทุกอย่างที่ "เควสนี้เอง" ทำให้เกิดขึ้นก่อน
  if (reward.streakMilestone != null) {
    HapticFeedback.mediumImpact();
    await _showStreakMilestoneDialog(context, reward.streakMilestone!);
  }
}

// เด้งแสดงความยินดีตอนได้เหรียญใหม่ — รองรับกรณีได้หลายเหรียญพร้อมกันด้วย
Future<void> _showMedalDialog(BuildContext context, List<UnlockedMedal> medals) {
  return LiquidGlassDialog.show<void>(
    context: context,
    icon: const _BounceIn(child: Icon(Icons.emoji_events, color: Colors.amber, size: 32)),
    backgroundEffect: const ParticleBurstOverlay(
      color: Colors.amber,
      particleCount: 14,
      duration: Duration(milliseconds: 700),
    ),
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

// เด้งฉลองตอนเลเวลอัพ — คนละหน้าตากับ popup เหรียญ (อนุภาคเยอะกว่า/สีเขียวแทนสีทอง) ให้รู้สึกแยกกันชัดเจน
Future<void> _showLevelUpDialog(BuildContext context, int newLevel) {
  return LiquidGlassDialog.show<void>(
    context: context,
    icon: const _BounceIn(child: Icon(Icons.military_tech, color: Colors.greenAccent, size: 40)),
    backgroundEffect: const ParticleBurstOverlay(
      color: Colors.greenAccent,
      particleCount: 26,
      duration: Duration(milliseconds: 1000),
    ),
    title: 'Level Up!',
    content: Text(
      "You've reached Level $newLevel",
      textAlign: TextAlign.center,
      style: LiquidGlassDialog.messageStyle,
    ),
    actions: [
      LiquidGlassAction(label: 'Awesome', color: Colors.green, onPressed: () => Navigator.pop(context)),
    ],
  );
}

// เด้งฉลองตอนครบ milestone ของ Daily Streak (วัน 7/14/21/30) — คนละหน้าตากับ level-up/medal
// (สีส้ม/ไอคอนไฟ ให้รู้สึกแยกกันชัดเจนกับอีก 2 อย่าง)
Future<void> _showStreakMilestoneDialog(BuildContext context, StreakMilestoneReward streak) {
  return LiquidGlassDialog.show<void>(
    context: context,
    icon: const _BounceIn(child: Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 40)),
    backgroundEffect: const ParticleBurstOverlay(
      color: Colors.orangeAccent,
      particleCount: 20,
      duration: Duration(milliseconds: 800),
    ),
    title: '${streak.day}-Day Streak!',
    content: Text(
      '+${streak.points} points, +${streak.xp} XP'
      '${streak.itemType != null ? '\n+ a bonus item in your Inventory' : ''}',
      textAlign: TextAlign.center,
      style: LiquidGlassDialog.messageStyle,
    ),
    actions: [
      LiquidGlassAction(label: 'Nice', color: Colors.orange, onPressed: () => Navigator.pop(context)),
    ],
  );
}

// เด้งเข้ามาแบบยืดหยุ่น (elasticOut) ใช้กับไอคอนใน dialog ฉลอง — ตอน t เกิน 1 ชั่วครู่ (จังหวะเด้งเกินเป้า
// ของ elasticOut) ไม่ scale ติดลบ/เกินจริงจนดูแปลก เพราะ Transform.scale รับค่าได้ตรงๆ อยู่แล้ว
class _BounceIn extends StatelessWidget {
  final Widget child;
  const _BounceIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}
