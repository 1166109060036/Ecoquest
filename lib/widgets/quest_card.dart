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
          // เควส party ไม่ได้กด "เข้าร่วม" ตรงนี้แล้ว — ต้องกดสร้างห้องก่อน คนอื่นถึงเข้าร่วมได้
          // (การ์ดนี้เป็นแค่ template ไม่ใช่ห้องจริง — ห้องที่เข้าร่วมได้แสดงเป็น PartyRoomCard
          // ในลิสต์ Explore ตอนเลือก chip "Party" แทน ดู party_room_card.dart)
          actionLabel: 'Create Party',
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

  // ป้ายบนปุ่ม — เควส party ทำซ้ำได้วันละครั้งเหมือน quest รายวัน (เช็คจาก QuestHistory
  // ของวันนี้ ไม่ว่าจะทำผ่านห้องไหนก็ตาม) ถ้าวันนี้ทำไปแล้วก็สร้าง/เข้าร่วมห้องใหม่ไปก็ไม่ได้คะแนนซ้ำ
  String _actionLabel(_CategoryStyle style) => quest.completedToday ? 'Done' : style.actionLabel;

  bool get _actionEnabled => !quest.completedToday;

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
                              location: quest.location,
                              openPartyCount: quest.openPartyCount,
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

// การ์ดของ party quest ไม่มีวันเวลานัดหมายของตัวเองแล้ว (แต่ละห้องนัดคนละเวลากันได้)
// เลยโชว์แค่สถานที่ default กับจำนวนห้องที่เปิดรับอยู่ตอนนี้แทน กดเข้าไปดูห้องจริงได้ในหน้า Party
class _PartyEventInfoRow extends StatelessWidget {
  final String location;
  final int openPartyCount;

  const _PartyEventInfoRow({required this.location, required this.openPartyCount});

  @override
  Widget build(BuildContext context) {
    // แยกเป็น 2 บรรทัด (สถานที่ / จำนวนห้อง) แทนบรรทัดเดียว เพราะพื้นที่ในการ์ด
    // แคบมาก (โดนบีบด้วย DifficultyChip ด้านซ้ายกับปุ่ม Create Party ด้านขวา) ถ้ายัดรวมบรรทัด
    // เดียวจะล้นจอ (RenderFlex overflow) — ทุก Text ต้องมี Flexible+ellipsis กันเหนียวไว้ด้วย
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (location.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 10, color: Colors.grey),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  location,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.groups, size: 11, color: Colors.grey),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                openPartyCount > 0 ? '$openPartyCount room${openPartyCount > 1 ? 's' : ''} open' : 'No rooms yet',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
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
