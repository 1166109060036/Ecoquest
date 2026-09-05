import 'package:flutter/material.dart';
import '../../models/inventory_item_model.dart';
import '../../models/achievement_model.dart';
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
      for (final medal in mockAchievementMedals)
        _InventoryEntry(
          icon: medal.icon,
          iconColor: medal.color,
          title: medal.title,
          description: medal.description,
          quantity: medal.quantity,
        ),
    ];

    // นับจำนวนช่องที่ใช้ไปทั้งหมด (ไอเทม + medal รวมกัน)
    final usedCapacity = allEntries.fold<int>(0, (sum, e) => sum + (e.quantity ?? 1));

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
      // TODO: ไปหน้ารายละเอียด Fridge จริงตอนออกแบบหน้านั้นเสร็จ
      // ตอนนี้แค่ให้กดเข้าได้ก่อนตามที่ตกลงกันไว้
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('หน้ารายละเอียด Fridge กำลังจะมาเร็วๆ นี้')),
      );
      return;
    }
    if (itemId == 'camera') {
      // TODO: เปิดกล้องถ่ายรูปจริงตอนต่อฟีเจอร์นี้
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ฟีเจอร์ถ่ายรูปกำลังจะมาเร็วๆ นี้')),
      );
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
