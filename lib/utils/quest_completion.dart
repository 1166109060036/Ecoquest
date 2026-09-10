import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/achievement_model.dart';
import '../models/quest_card_model.dart';
import '../providers/achievement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/party_provider.dart';
import '../providers/quest_provider.dart';

// สิ่งที่ต้องทำ "หลังทำ quest สำเร็จ" — เหมือนกันทั้ง 3 ที่ที่ทำ quest ได้
// (หน้า Explore, แผ่น Explore ในหน้า Home, และหน้า Fridge)
// รวมไว้ที่เดียวจะได้ไม่ต้องแก้ 3 จุดทุกครั้งที่เพิ่มอะไรตอนจบ quest
Future<void> handleQuestCompleted(BuildContext context, QuestReward reward) async {
  final authProvider = context.read<AuthProvider>();
  final achievementProvider = context.read<AchievementProvider>();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Quest complete! +${reward.points} points, +${reward.xp} XP')),
  );

  await Future.wait([
    // points/XP เปลี่ยนแล้ว ต้องโหลดโปรไฟล์ใหม่ให้หน้า Profile/Home โชว์เลขล่าสุด
    authProvider.refreshProfile(),
    // ความคืบหน้าเหรียญขยับทุกครั้งที่ทำ quest ถึงจะยังไม่ปลดล็อกก็ตาม
    achievementProvider.loadAchievements(),
  ]);

  if (!context.mounted || reward.newAchievements.isEmpty) return;

  HapticFeedback.mediumImpact();
  await _showMedalDialog(context, reward.newAchievements);
}

// กด "Join" บนการ์ด party quest — เข้าร่วมอีเวนต์ ไม่ใช่กดจบ quest ทันที
// (จะไปกดจบจริงที่หน้า Party ตอนไปร่วมงานแล้ว) ใช้ร่วมกันทั้งหน้า Explore
// และแผ่น Explore ในหน้า Home
Future<void> joinPartyQuest(BuildContext context, QuestCardModel quest) async {
  final partyProvider = context.read<PartyProvider>();
  final questProvider = context.read<QuestProvider>();

  if (quest.hasJoined) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You already joined this event. Open the Party tab.')),
    );
    return;
  }

  final joined = await partyProvider.join(quest.id);

  if (!context.mounted) return;

  if (!joined) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to join this event')),
    );
    return;
  }

  // โหลด quest ใหม่ให้การ์ดอัปเดตจำนวนคนเข้าร่วม + เปลี่ยนปุ่มเป็น "Joined"
  questProvider.loadQuests();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Joined! See the details in the Party tab.')),
  );
}

// เด้งแสดงความยินดีตอนได้เหรียญใหม่ — รองรับกรณีได้หลายเหรียญพร้อมกันด้วย
Future<void> _showMedalDialog(BuildContext context, List<UnlockedMedal> medals) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 26),
          const SizedBox(width: 10),
          Text(medals.length > 1 ? 'New medals!' : 'New medal!'),
        ],
      ),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    medal.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Check it in your Inventory.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nice', style: TextStyle(color: Colors.green)),
        ),
      ],
    ),
  );
}
