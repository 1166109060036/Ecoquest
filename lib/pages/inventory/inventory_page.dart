import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/inventory_card.dart';

// หน้า Inventory — ไอเทม (Camera, Fridge) และเหรียญ Achievement ที่ปลดล็อกแล้ว
// อยู่ในลิสต์เดียวกันทั้งหมด ไม่แยก section ตามดีไซน์
// สูงสุด 100 ช่อง (capacity) ตามดีไซน์
class InventoryPage extends StatelessWidget {
  // MainShell ส่ง callback นี้เข้ามา ใช้ตอนกดปุ่ม back เพื่อกลับไปแท็บ Home
  final ValueChanged<int>? onNavigateToTab;

  const InventoryPage({super.key, this.onNavigateToTab});

  static const int _maxCapacity = 100;
  static const int _homeTabIndex = 0; // ต้องตรงกับลำดับใน AppBottomNavBar

  Future<void> _onRefresh(BuildContext context) => Future.wait([
        context.read<InventoryProvider>().loadInventory(),
        context.read<AchievementProvider>().loadAchievements(),
      ]);

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    // เหรียญมาจาก backend จริง (โหลดไว้แล้วตั้งแต่ MainShell) — เรียงให้อันที่ปลดล็อกแล้วขึ้นก่อน
    final medals = [...context.watch<AchievementProvider>().achievements]
      ..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        // ยังไม่ปลดล็อกเหมือนกัน -> อันที่ใกล้ได้ขึ้นก่อน
        return (b.progress / b.required).compareTo(a.progress / a.required);
      });

    // รวมไอเทมปกติ + achievement medal เป็นลิสต์เดียวกัน
    final allEntries = <_InventoryEntry>[
      for (final item in inventoryProvider.items)
        _InventoryEntry(
          icon: item.icon,
          iconColor: Colors.black87,
          imageAsset: item.imageAsset,
          title: item.title,
          description: item.description,
          quantity: item.quantity,
          // itemType ที่ไม่รู้จัก (ยังไม่มีหน้าให้ไป) ไม่ต้องกดได้ — ไม่งั้นการ์ดจะขึ้นลูกศรเปล่าๆ
          onTap: _routeFor(item.itemType) == null
              ? null
              : () => Navigator.pushNamed(context, _routeFor(item.itemType)!),
        ),
      for (final medal in medals)
        _InventoryEntry(
          icon: medal.icon,
          // เหรียญที่ยังไม่ปลดล็อกทำเป็นสีเทา ให้แยกออกจากอันที่ได้แล้วชัดๆ
          iconColor: medal.unlocked ? medal.color : Colors.grey.shade400,
          title: medal.unlocked ? '${medal.title} Medal' : medal.title,
          description: medal.unlocked
              ? medal.description
              : '${medal.description}  (${medal.progress}/${medal.required})',
          // นับช่องเฉพาะเหรียญที่ได้จริงแล้ว อันที่ยังล็อกไม่ควรกินช่องกระเป๋า
          quantity: medal.unlocked ? 1 : null,
        ),
    ];

    // นับจำนวนช่องที่ใช้ไปทั้งหมด (ไอเทม + เหรียญที่ปลดล็อกแล้ว)
    final usedCapacity = allEntries.fold<int>(0, (sum, e) => sum + (e.quantity ?? 0));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // ---- หัวข้อ: ปุ่ม back + ชื่อหน้า + capacity ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => onNavigateToTab?.call(_homeTabIndex)),
                  const SizedBox(width: 10),
                  const Text('Inventory',
                      style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$usedCapacity / $_maxCapacity',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: inventoryProvider.isLoading && allEntries.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : allEntries.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () => _onRefresh(context),
                          color: Colors.green,
                          // ต้อง scrollable เสมอ ไม่งั้นตอนลิสต์ว่างจะดึงลง refresh ไม่ได้
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              _EmptyState(errorMessage: inventoryProvider.errorMessage),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _onRefresh(context),
                          color: Colors.green,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: allEntries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final entry = allEntries[index];
                              return InventoryCard(
                                icon: entry.icon,
                                iconColor: entry.iconColor,
                                imageAsset: entry.imageAsset,
                                title: entry.title,
                                description: entry.description,
                                quantity: entry.quantity,
                                onTap: entry.onTap,
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

  // เส้นทางที่กดไอเทมแล้วต้องไป — itemType อื่นที่ไม่รู้จัก (backend เพิ่มมาใหม่) คืน null
  String? _routeFor(String itemType) => switch (itemType) {
        'fridge' => '/fridge',
        'camera' => '/camera',
        _ => null,
      };
}

// helper ภายในไฟล์นี้ ใช้รวมไอเทม+medal ให้อยู่ในรูปแบบเดียวกันก่อน render
class _InventoryEntry {
  final IconData icon;
  final Color iconColor;
  final String? imageAsset;
  final String title;
  final String description;
  final int? quantity;
  final VoidCallback? onTap;

  _InventoryEntry({
    required this.icon,
    required this.iconColor,
    this.imageAsset,
    required this.title,
    required this.description,
    this.quantity,
    this.onTap,
  });
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

// ลิสต์ว่างจริงๆ ไม่ควรเกิดขึ้น (Camera/Fridge เป็นไอเทมตั้งต้นที่ทุกคนต้องมี) แต่โหลดไม่ติด
// ตอนเปิดแอพครั้งแรกก็เป็นไปได้ — โชว์ข้อความนี้กันหน้าว่างเปล่าไปเลย
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
            Icon(
              failed ? Icons.cloud_off : Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'No items in your inventory yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Pull down to try again',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
