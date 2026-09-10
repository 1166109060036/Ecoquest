import 'package:flutter/material.dart';
import '../models/quest_card_model.dart';

class QuestCard extends StatelessWidget {
  final QuestCardModel quest;
  final VoidCallback? onAction;
  final VoidCallback? onTap; // กดที่ตัวการ์ด = เปิดหน้ารายละเอียด (คนละอันกับปุ่ม Start/Join)

  const QuestCard({super.key, required this.quest, this.onAction, this.onTap});

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

  // ป้ายบนปุ่ม + เปิด/ปิดปุ่ม — party quest มีสถานะเพิ่มจาก solo คือ "เข้าร่วมแล้ว" กับ "เต็ม"
  String _actionLabel(_CategoryStyle style) {
    if (quest.completedToday) return 'Done';
    if (quest.category == QuestCardCategory.party) {
      if (quest.hasJoined) return 'Joined';
      if (quest.isFull) return 'Full';
    }
    return style.actionLabel;
  }

  // เข้าร่วมแล้วก็ไม่ต้องกดซ้ำ (ไปกดจบที่หน้า Party แทน) และเต็มแล้วก็กดไม่ได้
  bool get _actionEnabled {
    if (quest.completedToday) return false;
    if (quest.category == QuestCardCategory.party) {
      return !quest.hasJoined && !quest.isFull;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          // ---- รูปปก quest (ตัวเดียวกับที่ใช้ในหน้ารายละเอียด) ----
          _QuestThumbnail(imageAsset: quest.coverImageAsset),
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
                    // ความยาก — ให้ผู้เล่นตัดสินใจได้ตั้งแต่ยังไม่กดเข้าไปดูรายละเอียด
                    DifficultyChip(difficulty: quest.difficulty),
                    const SizedBox(width: 6),
                    Expanded(
                      child: quest.category == QuestCardCategory.solo
                          ? _SoloInfoRow(
                              isDaily: quest.isDaily,
                              completedToday: quest.completedToday,
                            )
                          : _PartyEventInfoRow(
                              dateLabel: quest.dateLabel,
                              timeLabel: quest.timeLabel,
                              capacityLabel: quest.capacityLabel,
                            ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      // quest รายวันที่ทำไปแล้ววันนี้ -> กดซ้ำไม่ได้จนกว่าจะข้ามวัน
                      onPressed: _actionEnabled ? onAction : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: style.actionColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        elevation: 0,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _actionLabel(style),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ป้ายความยากของ quest — ใช้ทั้งในการ์ดและหน้ารายละเอียด
// สีสื่อความหมายตรงตัว: เขียว = ง่าย, ส้ม = ปานกลาง, แดง = ยาก
class DifficultyChip extends StatelessWidget {
  final String difficulty; // easy / medium / hard (ค่าที่ backend ส่งมา)
  final bool large; // true = ขนาดสำหรับหน้ารายละเอียด

  const DifficultyChip({super.key, required this.difficulty, this.large = false});

  @override
  Widget build(BuildContext context) {
    if (difficulty.isEmpty) return const SizedBox.shrink();

    final (label, color) = switch (difficulty) {
      'easy' => ('Easy', Colors.green),
      'medium' => ('Medium', Colors.orange),
      'hard' => ('Hard', Colors.redAccent),
      // เผื่อ backend เพิ่มระดับใหม่มาแล้วแอพยังไม่รู้จัก
      _ => (difficulty, Colors.blueGrey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 7, vertical: large ? 4 : 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: large ? 12 : 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// รูปปก quest ในการ์ด — ถ้า quest ยังไม่มีรูป (หรือหาไฟล์ไม่เจอ) จะ fallback เป็นกล่องเทาเหมือนเดิม
class _QuestThumbnail extends StatelessWidget {
  final String? imageAsset;
  const _QuestThumbnail({required this.imageAsset});

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageAsset == null) return _placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imageAsset!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
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

// เดิมช่องนี้เคยเป็นแถบ Energy แต่ระบบ Energy ถูกตัดออกจากดีไซน์แล้ว
// ตอนนี้ใช้บอกสถานะ quest รายวันแทน (ยังทำได้ / วันนี้ทำไปแล้ว)
class _SoloInfoRow extends StatelessWidget {
  final bool isDaily;
  final bool completedToday;

  const _SoloInfoRow({required this.isDaily, required this.completedToday});

  @override
  Widget build(BuildContext context) {
    if (!isDaily) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(
          completedToday ? Icons.check_circle : Icons.refresh,
          size: 12,
          color: completedToday ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          completedToday ? 'Completed today' : 'Once per day',
          style: TextStyle(
            fontSize: 10,
            color: completedToday ? Colors.green : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
