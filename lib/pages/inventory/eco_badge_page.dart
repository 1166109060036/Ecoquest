import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/achievement_model.dart';
import '../../providers/achievement_provider.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/medal_badge.dart';
import '../../widgets/skeleton_box.dart';

// หน้าดูเหรียญ Achievement — เข้าจากไอเทม Eco Badge ในหน้า Inventory (แนวเดียวกับที่ไอเทม Fridge เปิดไป FridgePage)
// เหรียญหลายขั้น (6 ต.ค. 2026): แต่ละหมวดมี Bronze / Silver / Gold — โชว์ทุกหมวด เหรียญที่ได้แล้วขึ้นก่อน
// พร้อมแถบความคืบหน้าไปขั้นถัดไป (เดิมโชว์แค่ที่ปลดล็อกแล้ว แต่พอมีหลายขั้น "อีกกี่ครั้งถึงขั้นถัดไป" คือเป้าที่ทำให้อยากเล่นต่อ)
class EcoBadgePage extends StatelessWidget {
  const EcoBadgePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AchievementProvider>();
    // ได้ขั้นสูงกว่าขึ้นก่อน → ใกล้ขั้นถัดไปกว่าขึ้นก่อน
    final medals = [...provider.achievements]..sort((a, b) {
        final byTier = b.tiersUnlocked.compareTo(a.tiersUnlocked);
        if (byTier != 0) return byTier;
        return (b.progress / b.required).compareTo(a.progress / a.required);
      });
    final earned = medals.fold<int>(0, (sum, m) => sum + m.tiersUnlocked);
    final total = medals.fold<int>(0, (sum, m) => sum + m.tiersTotal);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  const Text('Eco Badge',
                      style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$earned / $total',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading && provider.achievements.isEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, _) => const InventoryCardSkeleton(),
                    )
                  : medals.isEmpty
                      ? LeafRefreshIndicator(
                          onRefresh: () => context.read<AchievementProvider>().loadAchievements(),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              _EmptyState(errorMessage: provider.errorMessage),
                            ],
                          ),
                        )
                      : LeafRefreshIndicator(
                          onRefresh: () => context.read<AchievementProvider>().loadAchievements(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: medals.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) => _MedalTierCard(medal: medals[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// การ์ดเหรียญ 1 หมวด: ไอคอนสีตามขั้นสูงสุด + ป้ายขั้น + 3 ขั้น (Bronze/Silver/Gold) + แถบไปขั้นถัดไป
class _MedalTierCard extends StatelessWidget {
  final AchievementMedalModel medal;
  const _MedalTierCard({required this.medal});

  @override
  Widget build(BuildContext context) {
    final earned = medal.tier != null;
    final ratio = medal.required == 0 ? 1.0 : (medal.progress / medal.required).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // เหรียญจริง: โลหะตามขั้นสูงสุดที่ได้ + ริบบิ้นสีหมวด (ยังไม่ได้ = เหรียญเทาจาง)
          MedalBadge(icon: medal.icon, tier: medal.tier, ribbonColor: medal.color, size: 66),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        medal.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: earned ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    if (earned) ...[
                      const SizedBox(width: 8),
                      _TierChip(label: medal.tierLabel ?? '', color: medal.tierColor),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // 3 ขั้น: เหรียญจิ๋ว (ไม่มีริบบิ้น) + จำนวนที่ต้องทำ
                Row(
                  children: [
                    for (final t in medal.tiers) ...[
                      MedalBadge(
                        icon: medal.icon,
                        tier: t.unlocked ? t.tier : null,
                        ribbonColor: medal.color,
                        size: 22,
                        showRibbon: false,
                      ),
                      const SizedBox(width: 3),
                      Text('${t.required}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: t.unlocked ? Colors.grey.shade700 : Colors.grey.shade400,
                          )),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (medal.maxed)
                  Text('All tiers complete · ${medal.count} quests',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: medalTierColor('gold')))
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(medalTierColor(medal.nextTier)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${medal.progress} / ${medal.required} to ${medal.nextTierLabel ?? ''} · ${medal.description}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TierChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_left, color: Colors.black54, size: 22),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? errorMessage;
  const _EmptyState({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathingIcon(
              child: Icon(
                failed ? Icons.cloud_off : Icons.military_tech_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'No medals collected yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              failed ? 'Pull down to try again' : 'Complete quests to earn your first Achievement medal',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
