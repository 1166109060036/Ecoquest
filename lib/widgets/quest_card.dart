import 'package:flutter/material.dart';
import '../models/quest_card_model.dart';
import 'check_in_ring.dart';
import 'pressable_scale.dart';

class QuestCard extends StatelessWidget {
  final QuestCardModel quest;
  final VoidCallback? onAction;
  final VoidCallback? onTap; // กดที่ตัวการ์ด = เปิดหน้ารายละเอียด (คนละอันกับปุ่ม Start/Join)
  // true เฉพาะตอนใช้ในหน้า Progress — การ์ดในหน้านั้น inProgress เป็น true ทุกใบอยู่แล้วโดยดีไซน์
  // (ไม่ใช่สถานะ "กดซ้ำไม่ได้" แบบตอนอยู่ในหน้า Explore) ปุ่มเลยต้องกดได้และเปลี่ยนเป็น Complete แทน
  final bool progressMode;
  // ใส่มา = รูปปกบินต่อเข้าหน้ารายละเอียดตอนกดการ์ด (Hero) — ต้องตรงกับ heroTag ที่ส่งให้ QuestDetailPage
  // สร้างด้วย questCoverHeroTag() เสมอ (แต่ละหน้าใส่ชื่อหน้าตัวเองไว้ในแท็ก เพราะแผ่น Explore ในหน้า Home กับหน้า
  // Explore อยู่ใน IndexedStack route เดียวกัน การ์ดเควสเดียวกันจากสองที่จะได้ไม่ชนแท็กกัน)
  final String? heroTag;

  const QuestCard({
    super.key,
    required this.quest,
    this.onAction,
    this.onTap,
    this.progressMode = false,
    this.heroTag,
  });

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

  // ป้ายบนปุ่ม — เควสทำซ้ำได้ไม่จำกัดต่อวันแล้ว (ไม่มีสถานะ "Done" อีก) ล็อกแค่ตอนกำลังทำอยู่ (กด Start ไว้แล้ว
  // แต่ยังไม่ Complete) — ต้องไปกด Complete ที่หน้า Progress แทน
  //
  // เควสหลายวัน (Food Saver 3/7): ในหน้า Progress กดได้วันละครั้ง = "Check in" / เช็คอินแล้ว = "Checked in"
  // ส่วนใน Explore ระหว่างทาง (ยังไม่ครบ) ให้เป็น "In progress" แม้วันนี้จะเช็คอินแล้ว — ยังไม่จบ
  String _actionLabel(_CategoryStyle style) {
    if (quest.isMultiDay && progressMode) return quest.checkedInToday ? 'Checked in' : 'Check in';
    if (quest.isMultiDay && quest.inProgress) return 'In progress';
    if (progressMode) return 'Complete';
    if (quest.inProgress) return 'In progress';
    return style.actionLabel;
  }

  bool get _actionEnabled {
    if (quest.isMultiDay && progressMode) return !quest.checkedInToday;
    if (quest.isMultiDay && quest.inProgress) return false;
    if (progressMode) return true;
    return !quest.inProgress;
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
          _QuestThumbnail(imageAsset: quest.coverImageAsset, heroTag: heroTag),
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
                        // เควสหลายวัน = แต้มรวมทั้งเควส (รายวัน + โบนัสจบ) ให้เห็นว่าคุ้มกว่าเควสวันเดียว
                        Text(
                          '+${quest.displayPoints.toString().padLeft(3, '0')} P',
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
                              timesToday: quest.timesToday,
                              durationDays: quest.durationDays,
                              daysDone: quest.daysDone,
                              checkedInToday: quest.checkedInToday,
                              progressMode: progressMode,
                              comboMultiplier: quest.comboMultiplier,
                              completionBonus: quest.checkInReward?.completionBonus.points,
                            )
                          : _PartyEventInfoRow(
                              location: quest.location,
                              openPartyCount: quest.openPartyCount,
                            ),
                    ),
                    const SizedBox(width: 8),
                    PressableScale(
                      child: ElevatedButton(
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

// แท็ก Hero ของรูปปกเควส — page = ชื่อหน้าที่การ์ดอยู่ ('home' / 'explore' / 'progress')
String questCoverHeroTag(String page, String questId) => 'quest-cover-$page-$questId';

// รูปปกระหว่างบินจากการ์ดไปหน้ารายละเอียด (และบินกลับ) — มุมมนค่อยๆ เปลี่ยน 12 -> 0 ตามทาง ไม่งั้นตอนบินจะ
// เป็นสี่เหลี่ยมมุมแหลมตั้งแต่ออกจากการ์ด (ขากลับ animation วิ่ง 1 -> 0 มุมเลยค่อยๆ มนกลับเอง)
// ใช้รูปฝั่งหน้ารายละเอียดเสมอทั้งขาไปและขากลับ (push = toHero, pop = fromHero) เพราะรูปฝั่งการ์ดล็อกขนาด 64×64
// ไว้ ขยายตามกรอบที่บินไม่ได้ — รูปฝั่งหน้ารายละเอียดเป็น BoxFit.cover ไม่ล็อกขนาด
Widget questCoverFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final hero = (direction == HeroFlightDirection.push ? toHeroContext : fromHeroContext).widget as Hero;
  return AnimatedBuilder(
    animation: animation,
    builder: (_, child) => ClipRRect(
      borderRadius: BorderRadius.circular(12 * (1 - animation.value)),
      child: child,
    ),
    child: hero.child,
  );
}

// รูปปก quest ในการ์ด — ถ้า quest ยังไม่มีรูป (หรือหาไฟล์ไม่เจอ) จะ fallback เป็นกล่องเทาเหมือนเดิม
class _QuestThumbnail extends StatelessWidget {
  final String? imageAsset;
  final String? heroTag;
  const _QuestThumbnail({required this.imageAsset, this.heroTag});

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

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imageAsset!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      ),
    );
    if (heroTag == null) return image;
    return Hero(tag: heroTag!, flightShuttleBuilder: questCoverFlightShuttle, child: image);
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
  final int timesToday;
  final int durationDays;
  final int daysDone;
  final bool checkedInToday;
  final bool progressMode;
  // Daily Variety Combo ถ้าทำเควสนี้ตอนนี้ (backend/utils/combo.js) — โชว์เฉพาะตอนไม่ใช่ ×1
  final double? comboMultiplier;
  // โบนัสจบเควสหลายวัน (backend/utils/checkInRewards.js) — null = backend เก่า / เควสวันเดียว
  final int? completionBonus;

  const _SoloInfoRow({
    required this.timesToday,
    this.durationDays = 1,
    this.daysDone = 0,
    this.checkedInToday = false,
    this.progressMode = false,
    this.comboMultiplier,
    this.completionBonus,
  });

  @override
  Widget build(BuildContext context) {
    // เควสหลายวัน: หน้า Progress โชว์ความคืบหน้า "Day 2/7" / หน้า Explore บอกว่าเป็นเควสกี่วัน
    if (durationDays > 1) {
      // เช็คอินวันนี้แล้ว = ไอคอนติ๊กสีเขียวบอกอยู่แล้ว ไม่ต่อข้อความยาว (ช่องนี้แคบ ปุ่มด้านขวากินที่เยอะ)
      final label = progressMode ? 'Day $daysDone/$durationDays' : '$durationDays-day check-in';
      final done = progressMode && checkedInToday;
      final bonus = completionBonus;
      // หน้า Explore: ชิปสีส้มบอกโบนัสจบเควสให้เด่น — ดึงให้คนเลือกเควสหลายวัน (ผู้ใช้สั่ง 6 ต.ค. 2026)
      if (!progressMode && bonus != null && bonus > 0) {
        return Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '$durationDays days · +$bonus bonus',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          // หน้า Progress = วงแหวนเล็กบอกว่าเช็คอินไปกี่ช่องแล้ว (ช่องใหม่เติมสีเองตอนเช็คอินแล้วลิสต์โหลดใหม่)
          if (progressMode)
            CheckInRing(total: durationDays, done: daysDone, size: 14, strokeWidth: 2.4)
          else
            const Icon(Icons.event_repeat, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: done ? Colors.green : Colors.grey.shade600),
            ),
          ),
        ],
      );
    }

    // ทำซ้ำได้ไม่จำกัดต่อวัน — บอกแค่ว่าวันนี้ทำไปแล้วกี่ครั้ง (ยังไม่เคยทำวันนี้ = "Repeatable")
    final done = timesToday > 0;
    final combo = comboMultiplier;
    final showCombo = !progressMode && combo != null && combo != 1;
    return Row(
      children: [
        // คอมโบ: เขียว = เควสใหม่ของวันได้แต้มเพิ่ม / ส้ม = ทำซ้ำได้แต้มลดลง
        if (showCombo) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: combo > 1 ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: combo > 1 ? Colors.green.shade300 : Colors.orange.shade300),
            ),
            child: Text(
              formatMultiplier(combo),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: combo > 1 ? Colors.green.shade700 : Colors.orange.shade800,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Icon(
          done ? Icons.check_circle : Icons.refresh,
          size: 12,
          color: done ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            done ? 'Done $timesToday× today' : 'Repeatable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: done ? Colors.green : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
