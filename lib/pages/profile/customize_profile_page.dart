import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/cosmetics.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_in.dart';

// key ที่ backend ใช้เก็บ cosmetics ต่อ slot (PUT /inventory/cosmetics) — ต้องตรงกับ
// backend/models/User.js#CosmeticsSchema เป๊ะๆ
String _slotKey(CosmeticSlot slot) => switch (slot) {
  CosmeticSlot.frame => 'frame',
  CosmeticSlot.nameStyle => 'nameStyle',
  CosmeticSlot.background => 'background',
  CosmeticSlot.effect => 'effect',
};

String _slotLabel(CosmeticSlot slot) => switch (slot) {
  CosmeticSlot.frame => 'Avatar Frame',
  CosmeticSlot.nameStyle => 'Name Style',
  CosmeticSlot.background => 'Profile Background',
  CosmeticSlot.effect => 'Ambient Effect',
};

// หน้าใส่/ถอดของตกแต่งโปรไฟล์ — เข้าจากปุ่ม "Custom Profile" ในหน้า Profile ของตัวเองเท่านั้น
// (ย้ายมาจากหน้า Inventory เดิม เพราะของตกแต่งเป็นเรื่องของโปรไฟล์โดยตรง ไม่ใช่ไอเทมที่ "ใช้" แบบ
// ไอเทม Energy) ซื้อของตกแต่งยังทำที่แท็บ Decorations ในหน้า Shop เหมือนเดิม — หน้านี้แค่ใส่/ถอด
// ของที่ซื้อไว้แล้วเท่านั้น (ดูของที่มีอยู่จริงจาก GET /api/inventory ตัวเดียวกับหน้า Inventory)
class CustomizeProfilePage extends StatelessWidget {
  const CustomizeProfilePage({super.key});

  Future<void> _onRefresh(BuildContext context) => Future.wait([
    context.read<InventoryProvider>().loadInventory(),
    context.read<AuthProvider>().refreshProfile(),
  ]);

  // กด Equip/Equipped สลับใส่-ถอดของตกแต่ง 1 ชิ้น — กดของที่ใส่อยู่แล้วซ้ำ = ถอดออก
  Future<void> _onEquip(
    BuildContext context,
    InventoryItemModel item, {
    required bool isEquipped,
  }) async {
    final inventoryProvider = context.read<InventoryProvider>();
    final success = await inventoryProvider.equipCosmetic(
      item.itemType,
      slotKey: _slotKey(item.slot!),
      equip: !isEquipped,
    );
    if (!context.mounted) return;

    if (!success) {
      showBubbleToast(
        context,
        inventoryProvider.errorMessage ?? 'Failed to update cosmetics',
      );
      return;
    }

    // cosmetics ที่ใส่อยู่เก็บใน AuthProvider.user คนละที่กับ inventory — ต้องรีเฟรชโปรไฟล์เอง
    // (แบบเดียวกับที่หน้า Shop เรียก refreshProfile() ต่อหลังซื้อของ)
    await context.read<AuthProvider>().refreshProfile();
    if (!context.mounted) return;

    showBubbleToast(
      context,
      isEquipped ? '${item.title} unequipped' : '${item.title} equipped',
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final equippedCosmetics = context.watch<AuthProvider>().user?.cosmetics;

    // จัดของตกแต่งที่มีอยู่จริง (ซื้อแล้ว) เป็นกลุ่มตาม slot เรียงตามลำดับของ CosmeticSlot.values
    // ให้ผลคงที่ทุกครั้ง — ของที่ยังไม่ได้ซื้อ (quantity 0) ไม่โชว์ที่นี่ ไปซื้อที่แท็บ Decorations
    // ในหน้า Shop ก่อน
    final cosmeticsBySlot = <CosmeticSlot, List<InventoryItemModel>>{};
    for (final item in inventoryProvider.items) {
      if (item.isCosmetic && item.quantity > 0) {
        cosmeticsBySlot.putIfAbsent(item.slot!, () => []).add(item);
      }
    }

    // รายการที่จะ render จริง — ผสม header (String) กับการ์ดไอเทม (_CosmeticEntry) ไว้ในลิสต์เดียว
    final listItems = <Object>[];
    for (final slot in CosmeticSlot.values) {
      final slotItems = cosmeticsBySlot[slot];
      if (slotItems == null || slotItems.isEmpty) continue;

      final equippedItemType = switch (slot) {
        CosmeticSlot.frame => equippedCosmetics?.frame,
        CosmeticSlot.nameStyle => equippedCosmetics?.nameStyle,
        CosmeticSlot.background => equippedCosmetics?.background,
        CosmeticSlot.effect => equippedCosmetics?.effect,
      };

      listItems.add(_slotLabel(slot));
      for (final item in slotItems) {
        listItems.add(
          _CosmeticEntry(
            item: item,
            isEquipped: item.itemType == equippedItemType,
          ),
        );
      }
    }

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
                  const Text(
                    'Custom Profile',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: inventoryProvider.isLoading && listItems.isEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, _) => const InventoryCardSkeleton(),
                    )
                  : listItems.isEmpty
                  ? LeafRefreshIndicator(
                      onRefresh: () => _onRefresh(context),
                      // ต้อง scrollable เสมอ ไม่งั้นตอนลิสต์ว่างจะดึงลง refresh ไม่ได้
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.15,
                          ),
                          _EmptyState(
                            errorMessage: inventoryProvider.errorMessage,
                          ),
                        ],
                      ),
                    )
                  : LeafRefreshIndicator(
                      onRefresh: () => _onRefresh(context),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: listItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final listItem = listItems[index];

                          if (listItem is String) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 2),
                              child: Text(
                                listItem,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          final entry = listItem as _CosmeticEntry;
                          final item = entry.item;
                          return FadeSlideIn(
                            key: ValueKey(item.itemType),
                            delay: Duration(
                              milliseconds: 40 * index.clamp(0, 10),
                            ),
                            child: InventoryCard(
                              icon: item.icon,
                              iconColor: item.accentColor,
                              imageAsset: item.imageAsset,
                              title: item.title,
                              description: item.description,
                              actionLabel: entry.isEquipped
                                  ? 'Equipped'
                                  : 'Equip',
                              actionColor: entry.isEquipped
                                  ? Colors.grey
                                  : item.accentColor,
                              onAction: () => _onEquip(
                                context,
                                item,
                                isEquipped: entry.isEquipped,
                              ),
                              equipped: entry.isEquipped,
                              actionBusy:
                                  inventoryProvider.busyItemType ==
                                  item.itemType,
                            ),
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

class _CosmeticEntry {
  final InventoryItemModel item;
  final bool isEquipped;
  _CosmeticEntry({required this.item, required this.isEquipped});
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
        child: const Icon(Icons.arrow_back, color: Colors.black54, size: 22),
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
                failed ? Icons.cloud_off : Icons.auto_awesome_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'No decorations yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              failed ? 'Pull down to try again' : 'Buy some from the Shop',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
