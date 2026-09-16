import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/achievement_provider.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/skeleton_box.dart';

// หน้าดูเหรียญ Achievement ที่ปลดล็อกแล้ว — เข้าจากไอเทม Eco Badge ในหน้า Inventory
// (แนวเดียวกับที่ไอเทม Fridge เปิดไป FridgePage) ดูอย่างเดียว ไม่มีปุ่มทำอะไรในนี้
// เหรียญที่ยังไม่ปลดล็อกไม่โชว์ที่นี่ — ไอเทมนี้เป็น "ที่เก็บ" เฉพาะเหรียญที่ทำสำเร็จแล้วเท่านั้น
// (อยากดูความคืบหน้าของเหรียญที่ยังไม่ปลดล็อก ดูได้จากหน้า Achievements เดิม)
class EcoBadgePage extends StatelessWidget {
  const EcoBadgePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AchievementProvider>();
    // ล่าสุดขึ้นก่อน — เหรียญที่เพิ่งได้มาควรเห็นบนสุด
    final unlocked = [...provider.unlocked]..sort((a, b) {
        if (a.unlockedAt == null || b.unlockedAt == null) return 0;
        return b.unlockedAt!.compareTo(a.unlockedAt!);
      });

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
                    child: Text('${unlocked.length} / ${provider.achievements.length}',
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
                  : unlocked.isEmpty
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
                            itemCount: unlocked.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final medal = unlocked[index];
                              return InventoryCard(
                                icon: medal.icon,
                                iconColor: medal.color,
                                title: '${medal.title} Medal',
                                description: medal.description,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
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
