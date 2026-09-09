import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item_model.dart';
import '../../providers/achievement_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    // เหรียญมาจาก backend จริง (โหลดไว้แล้วตั้งแต่ MainShell) — เรียงให้อันที่ปลดล็อกแล้วขึ้นก่อน
    final medals = [...context.watch<AchievementProvider>().achievements]
      ..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        // ยังไม่ปลดล็อกเหมือนกัน -> อันที่ใกล้ได้ขึ้นก่อน
        return (b.progress / b.required).compareTo(a.progress / a.required);
      });

    // รวมไอเทมปกติ + achievement medal เป็นลิสต์เดียวกัน
    final allEntries = <_InventoryEntry>[
      for (final item in mockInventoryItems)
        _InventoryEntry(
          icon: item.icon,
          iconColor: Colors.black87,
          imageAsset: item.imageAsset,
          title: item.title,
          description: item.description,
          quantity: item.quantity,
          onTap: () => _onItemTap(context, item.id),
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
          ],
        ),
      ),
    );
  }

  void _onItemTap(BuildContext context, String itemId) {
    if (itemId == 'fridge') {
      Navigator.pushNamed(context, '/fridge');
      return;
    }
    if (itemId == 'camera') {
      Navigator.pushNamed(context, '/camera');
    }
  }
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
