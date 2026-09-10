import 'package:flutter/material.dart';
import '../../models/quest_card_model.dart';
import '../../widgets/quest_card.dart';

// หน้ารายละเอียด quest — เข้าโดยกดที่ตัวการ์ด quest (ปุ่ม Start บนการ์ดยังทำงานเหมือนเดิม)
// โครงตามดีไซน์: รูปปกเต็มความกว้างด้านบน -> การ์ดขาวคร่อมขึ้นมาทับรูป -> ปุ่ม Start ล่างสุด
class QuestDetailPage extends StatelessWidget {
  final QuestCardModel quest;
  // ให้หน้าที่เรียกเป็นคนจัดการว่ากด Start แล้วทำอะไร (หน้า Explore/Home มี logic นี้อยู่แล้ว)
  final Future<void> Function(QuestCardModel quest) onStart;

  const QuestDetailPage({super.key, required this.quest, required this.onStart});

  _CategoryStyle get _style {
    switch (quest.category) {
      case QuestCardCategory.party:
        // ต้องสร้างห้องก่อน คนอื่นถึงจะเข้าร่วมได้ — ตรงกับปุ่มบนการ์ดในหน้า Explore/Home
        return const _CategoryStyle('Party', Colors.deepOrange, 'Create Party');
      case QuestCardCategory.event:
        return const _CategoryStyle('Event', Colors.blue, 'Join');
      case QuestCardCategory.solo:
        return const _CategoryStyle('Solo', Colors.redAccent, 'Start');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final done = quest.completedToday;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CoverImage(quest: quest),
                  // ยกการ์ดขึ้นไปทับรูปนิดหน่อยตามดีไซน์
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MainCard(quest: quest, style: style),
                          const SizedBox(height: 14),
                          _RewardCard(quest: quest),
                          const SizedBox(height: 14),
                          _AboutCard(quest: quest),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ---- ปุ่ม Start ล่างสุด ----
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // quest รายวันที่ทำไปแล้ววันนี้ -> กดซ้ำไม่ได้จนกว่าจะข้ามเที่ยงคืน
                  onPressed: done
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await onStart(quest);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    done ? 'Completed today' : style.actionLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// รูปปก + ปุ่มย้อนกลับลอยทับมุมซ้ายบน
// ---------------------------------------------------------------------------
class _CoverImage extends StatelessWidget {
  final QuestCardModel quest;
  const _CoverImage({required this.quest});

  @override
  Widget build(BuildContext context) {
    final asset = quest.coverImageAsset;

    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (asset != null)
            Image.asset(
              asset,
              fit: BoxFit.cover,
              // quest ที่ยังไม่มีไฟล์รูป -> ใช้พื้นเขียวอ่อนแทน ไม่ให้หน้าพัง
              errorBuilder: (_, _, _) => const _CoverPlaceholder(),
            )
          else
            const _CoverPlaceholder(),
          // ไล่เฉดมืดด้านบน ให้ปุ่ม back อ่านออกไม่ว่ารูปจะสว่างแค่ไหน
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 110,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.green.shade100,
      child: Icon(Icons.eco, size: 56, color: Colors.green.shade300),
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดหลัก: ชื่อ quest + หมวด + กล่อง Quest Detail + แต้มที่ได้
// ---------------------------------------------------------------------------
class _MainCard extends StatelessWidget {
  final QuestCardModel quest;
  final _CategoryStyle style;

  const _MainCard({required this.quest, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest.title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  quest.subtitle,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ),
              DifficultyChip(difficulty: quest.difficulty, large: true),
            ],
          ),
          const SizedBox(height: 16),
          // ---- กล่องรายละเอียด (ตามดีไซน์ มี badge หมวดลอยมุมขวาบน) ----
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quest Detail',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Text(
                      quest.detail.isNotEmpty
                          ? quest.detail
                          : 'No description for this quest yet.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Point',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const Spacer(),
                        Text(
                          '+${quest.pointsReward} P',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: -4,
                top: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    style.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดรางวัล — แต้ม / XP / CO2 ที่ช่วยลดได้ (ข้อมูลจริงจาก backend ทั้งหมด)
// ---------------------------------------------------------------------------
class _RewardCard extends StatelessWidget {
  final QuestCardModel quest;
  const _RewardCard({required this.quest});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'What you get',
      child: Row(
        children: [
          _RewardItem(
            icon: Icons.stars_rounded,
            color: Colors.amber.shade700,
            value: '+${quest.pointsReward}',
            label: 'Points',
          ),
          _RewardItem(
            icon: Icons.trending_up_rounded,
            color: Colors.green,
            value: '+${quest.xpReward}',
            label: 'XP',
          ),
          _RewardItem(
            icon: Icons.cloud_outlined,
            color: Colors.lightBlue,
            value: '${quest.co2SavedKg.toStringAsFixed(1)} kg',
            label: 'CO₂ saved',
          ),
        ],
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _RewardItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดข้อมูลอื่นๆ — ความยาก / ผลกระทบ / ทำซ้ำได้แค่ไหน
// ---------------------------------------------------------------------------
class _AboutCard extends StatelessWidget {
  final QuestCardModel quest;
  const _AboutCard({required this.quest});

  String _pretty(String raw) {
    if (raw.isEmpty) return '-';
    // food_waste -> Food waste
    final spaced = raw.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'About this quest',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.category_outlined,
            label: 'Category',
            value: _pretty(quest.questCategory),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.fitness_center_rounded,
            label: 'Difficulty',
            value: _pretty(quest.difficulty),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.public_rounded,
            label: 'Impact',
            value: _pretty(quest.impact),
          ),
          if (quest.isDaily) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: quest.completedToday ? Icons.check_circle : Icons.refresh_rounded,
              label: 'Repeat',
              value: 'Once per day',
              // บอกให้ชัดว่ารอบใหม่เริ่มตอนเที่ยงคืน ไม่ใช่ครบ 24 ชั่วโมงหลังทำ
              note: quest.completedToday
                  ? 'Done today — available again after midnight'
                  : 'Resets at midnight',
              highlight: quest.completedToday,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.green : Colors.grey.shade600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87)),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(note!, style: TextStyle(fontSize: 10.5, color: color)),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CategoryStyle {
  final String label;
  final Color color;
  final String actionLabel;
  const _CategoryStyle(this.label, this.color, this.actionLabel);
}
