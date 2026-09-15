import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item_model.dart';
import '../../providers/achievement_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/quest_provider.dart';
import '../../widgets/inventory_card.dart';

// หน้า Inventory — ไอเทมที่มีอยู่จริงเท่านั้น (Camera, Fridge, Eco Badge, ไอเทม Energy ที่ซื้อไว้)
// สูงสุด 100 ช่อง (capacity) ตามดีไซน์
// ⚠️ ไอเทมที่ซื้อได้แต่ยังไม่เคยซื้อ (quantity 0) ไม่โชว์ที่นี่ — ไปโชว์เป็นการ์ดร้านค้าในหน้า Profile แทน
// (ดู _ItemShopCard ใน profile_page.dart) หน้านี้โชว์แค่ "ของที่มีอยู่จริง" เท่านั้น
// ⚠️ เหรียญ Achievement ไม่ได้อยู่ในลิสต์นี้แล้ว — ย้ายไปอยู่หลังไอเทม Eco Badge แทน (กดเข้าไปดู
// เหรียญที่ปลดล็อกแล้วได้ที่ EcoBadgePage เหมือนที่ไอเทม Fridge เปิดไป FridgePage)
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

  // ใช้ไอเทม Energy 1 ชิ้น — Super Energy ลบประวัติเควสวันนี้ทิ้ง (ทำใหม่ได้ แต่ต้องระวังกดพลาด)
  // เลยขึ้น confirm ก่อน ส่วน Red/Blue/Green แค่ตั้งบัฟชั่วคราว ไม่มีอะไรเสียหาย กดใช้ได้เลยไม่ต้อง confirm
  Future<void> _useItem(BuildContext context, InventoryItemModel item) async {
    if (item.itemType == 'super_energy') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Use Super Energy?'),
          content: const Text(
            "This resets all quests you've completed today so you can complete them again. "
            'Points/XP already earned stay — this just re-opens today\'s quests.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final inventoryProvider = context.read<InventoryProvider>();
    final success = await inventoryProvider.useItem(item.itemType);
    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(inventoryProvider.errorMessage ?? 'Failed to use this item')),
      );
      return;
    }

    // Super Energy เปลี่ยนสถานะ completedToday ของเควส -> ต้องโหลดลิสต์เควสใหม่ให้การ์ดอัปเดตตาม
    if (item.itemType == 'super_energy') {
      await context.read<QuestProvider>().loadQuests();
    }
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_successMessage(item.itemType))),
    );
  }

  String _successMessage(String itemType) => switch (itemType) {
        'red_energy' => '2x Points activated for 30 minutes!',
        'blue_energy' => '2x XP activated for 30 minutes!',
        'green_energy' => '2x Party Points activated for 30 minutes!',
        'super_energy' => "Today's quests were reset — go complete them again!",
        _ => 'Item used',
      };

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    // ไอเทมที่ซื้อได้แต่ยังไม่เคยซื้อ (quantity 0) ไม่โชว์ในกระเป๋า — โชว์แค่ของที่มีอยู่จริง
    final ownedItems = inventoryProvider.items.where((item) => item.quantity > 0);

    final allEntries = <_InventoryEntry>[
      for (final item in ownedItems)
        _InventoryEntry(
          itemType: item.itemType,
          icon: item.icon,
          iconColor: item.isUsable ? item.accentColor : Colors.black87,
          imageAsset: item.imageAsset,
          title: item.title,
          description: item.description,
          quantity: item.quantity,
          actionColor: item.accentColor,
          // ไอเทม Energy กดใช้ได้ (ปุ่ม Use) — Camera/Fridge/Eco Badge กดทั้งการ์ดเพื่อไปหน้าฟีเจอร์ของมันแทน
          onUse: item.isUsable ? () => _useItem(context, item) : null,
          onTap: item.isUsable || _routeFor(item.itemType) == null
              ? null
              : () => Navigator.pushNamed(context, _routeFor(item.itemType)!),
        ),
    ];

    // นับจำนวนช่องที่ใช้ไปทั้งหมด
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
                                actionLabel: 'Use',
                                actionColor: entry.actionColor,
                                onAction: entry.onUse,
                                actionBusy: entry.onUse != null &&
                                    inventoryProvider.busyItemType == entry.itemType,
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
        'eco_badge' => '/eco-badge',
        _ => null,
      };
}

// helper ภายในไฟล์นี้ ใช้รวมไอเทม+medal ให้อยู่ในรูปแบบเดียวกันก่อน render
class _InventoryEntry {
  final String itemType; // '' สำหรับ medal (ไม่มี itemType จริง แต่ medal ไม่มี onUse อยู่แล้วเลยไม่ใช้ค่านี้)
  final IconData icon;
  final Color iconColor;
  final String? imageAsset;
  final String title;
  final String description;
  final int? quantity;
  final VoidCallback? onTap;
  final VoidCallback? onUse;
  final Color actionColor;

  _InventoryEntry({
    this.itemType = '',
    required this.icon,
    required this.iconColor,
    this.imageAsset,
    required this.title,
    required this.description,
    this.quantity,
    this.onTap,
    this.onUse,
    this.actionColor = Colors.green,
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

// ลิสต์ว่างจริงๆ ไม่ควรเกิดขึ้น (Camera/Fridge/Eco Badge เป็นไอเทมตั้งต้นที่ทุกคนต้องมี) แต่โหลดไม่ติด
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
