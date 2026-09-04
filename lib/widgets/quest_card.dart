import 'package:flutter/material.dart';
import '../models/quest_card_model.dart';

class QuestCard extends StatelessWidget {
  final QuestCardModel quest;
  final VoidCallback? onAction;

  const QuestCard({super.key, required this.quest, this.onAction});

  _CategoryStyle get _style {
    switch (quest.category) {
      case QuestCardCategory.party:
        return _CategoryStyle(
          label: 'Party',
          badgeColor: Colors.deepOrange,
          actionLabel: 'Join',
          actionColor: Colors.green,
        );
      case QuestCardCategory.event:
        return _CategoryStyle(
          label: 'Event',
          badgeColor: Colors.blue,
          actionLabel: 'Join',
          actionColor: Colors.blue,
          titleColor: Colors.blue,
        );
      case QuestCardCategory.solo:
        return _CategoryStyle(
          label: 'Solo',
          badgeColor: Colors.redAccent,
          actionLabel: 'Start',
          actionColor: Colors.teal,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- thumbnail placeholder ----
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image_outlined, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          // ---- เนื้อหา ----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quest.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: style.titleColor ?? Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${quest.pointsReward.toString().padLeft(3, '0')} P',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: style.badgeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            style.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  quest.subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: quest.category == QuestCardCategory.solo
                          ? _SoloEnergyRow(progress: quest.energyProgress ?? 0)
                          : _PartyEventInfoRow(
                              dateLabel: quest.dateLabel,
                              timeLabel: quest.timeLabel,
                              capacityLabel: quest.capacityLabel,
                            ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: style.actionColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(style.actionLabel, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStyle {
  final String label;
  final Color badgeColor;
  final String actionLabel;
  final Color actionColor;
  final Color? titleColor;

  _CategoryStyle({
    required this.label,
    required this.badgeColor,
    required this.actionLabel,
    required this.actionColor,
    this.titleColor,
  });
}

class _PartyEventInfoRow extends StatelessWidget {
  final String? dateLabel;
  final String? timeLabel;
  final String? capacityLabel;

  const _PartyEventInfoRow({this.dateLabel, this.timeLabel, this.capacityLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
        const SizedBox(width: 3),
        Text('$dateLabel   $timeLabel',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(width: 10),
        const Icon(Icons.groups, size: 12, color: Colors.grey),
        const SizedBox(width: 3),
        Text(capacityLabel ?? '',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _SoloEnergyRow extends StatelessWidget {
  final double progress;
  const _SoloEnergyRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt, size: 13, color: Colors.green),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Colors.green),
            ),
          ),
        ),
      ],
    );
  }
}
