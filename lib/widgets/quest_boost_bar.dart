import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quest_card_model.dart';
import '../pages/bingo/bingo_page.dart';
import '../providers/bingo_provider.dart';
import '../providers/quest_provider.dart';
import 'bubble_toast.dart';
import 'pressable_scale.dart';

// แถบบนลิสต์เควส (หน้า Explore + แผ่น Explore ในหน้า Home) — 2 กลไกที่ทำให้อยากทำเควสต่อ (30 ก.ย. 2026):
//   Eco Bingo รายสัปดาห์ (แตะเปิดการ์ด) + Daily Variety Combo วันนี้ (แตะดูกติกา)
// onStartQuest ส่งต่อให้หน้า Bingo — แตะช่องบนการ์ดแล้วกด Start ได้เลย (logic Start อยู่ที่หน้าที่เปิด)
class QuestBoostBar extends StatelessWidget {
  final Future<void> Function(QuestCardModel quest) onStartQuest;

  const QuestBoostBar({super.key, required this.onStartQuest});

  void _showComboRules(BuildContext context, ComboSummary combo) {
    showBubbleToast(
      context,
      'Each different quest today boosts your points (up to ${formatMultiplier(combo.maxMultiplier)}). '
      'Repeating a quest gives less each time.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = context.watch<BingoProvider>().card;
    final combo = context.watch<QuestProvider>().combo;
    if (card == null && combo == null) return const SizedBox.shrink();

    final lines = card?.completeLines.length ?? 0;
    return Row(
      children: [
        if (card != null)
          Expanded(
            child: _BoostPill(
              icon: Icons.grid_on_rounded,
              color: Colors.green.shade700,
              background: Colors.green.shade50,
              title: 'Eco Bingo',
              subtitle: card.full
                  ? 'Full card!'
                  : '${card.doneCount}/${card.questCount} · $lines line${lines == 1 ? '' : 's'}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BingoPage(onStartQuest: onStartQuest)),
              ),
            ),
          ),
        if (card != null && combo != null) const SizedBox(width: 8),
        if (combo != null)
          Expanded(
            child: _BoostPill(
              icon: Icons.bolt_rounded,
              color: Colors.orange.shade800,
              background: Colors.orange.shade50,
              title: combo.distinctToday == 0 ? 'Daily combo' : 'Combo · ${combo.distinctToday} today',
              // ต้นวันยังไม่มีคอมโบ (×1) — บอกกติกาแทนตัวเลขที่ไม่ชวนทำ
              subtitle: combo.distinctToday == 0
                  ? 'Mix quests = bonus'
                  : 'Next new quest ${formatMultiplier(combo.nextNewMultiplier)}',
              onTap: () => _showComboRules(context, combo),
            ),
          ),
      ],
    );
  }
}

class _BoostPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BoostPill({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
