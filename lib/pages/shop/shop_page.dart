import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/sound_service.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/inventory_card.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_in.dart';

// หน้า Item Shop — เข้าจากปุ่มร้านค้าข้างปุ่มกระดิ่งมุมขวาบนของหน้า Profile
// push ทับ MainShell เลยไม่มี bottom nav ให้เห็น (เหมือนหน้า Notification/Settings)
// หน้าตาอิงตามหน้า Inventory ทั้งหมด (พื้นหลัง/หัวข้อ/การ์ด) ต่างกันแค่ปุ่มขวาเป็น "ซื้อ" แทน "ใช้"
// ข้อมูลไอเทม+ราคาจริงจาก GET /api/inventory ตัวเดียวกับหน้า Inventory (คนละ view ของข้อมูลชุดเดียวกัน)
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  // ไอเทมที่เพิ่งซื้อสำเร็จ — เอาไว้ให้การ์ดนั้นเรืองแสงสั้นๆ (ดู celebrate ใน InventoryCard)
  // เคลียร์กลับเป็น null เองหลังผ่านไปสักพัก ไม่ต้องรอ user ทำอะไรต่อ
  String? _celebratingItemType;

  Future<void> _onRefresh(BuildContext context) => Future.wait([
        context.read<InventoryProvider>().loadInventory(),
        context.read<AuthProvider>().refreshProfile(),
      ]);

  Future<void> _buyItem(BuildContext context, InventoryItemModel item) async {
    final inventoryProvider = context.read<InventoryProvider>();
    final success = await inventoryProvider.buyItem(item.itemType);
    if (!context.mounted) return;

    if (!success) {
      showBubbleToast(context, inventoryProvider.errorMessage ?? 'Failed to buy this item');
      return;
    }

    // ซื้อเสร็จแล้วแต้มลด — รีเฟรช AuthProvider ให้ยอดแต้มที่โชว์ในแอพอัปเดตตามทันที
    await context.read<AuthProvider>().refreshProfile();
    if (!context.mounted) return;
    showBubbleToast(context, '${item.title} purchased');
    SoundService.instance.playBuySuccess();

    setState(() => _celebratingItemType = item.itemType);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _celebratingItemType = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final points = context.watch<AuthProvider>().user?.points ?? 0;
    // มีแค่ไอเทมที่ตั้งราคาไว้ (cost != null) เท่านั้นที่ซื้อได้ — starter item อย่าง Camera/Fridge ไม่ใช่ของขาย
    final shopItems = inventoryProvider.items.where((item) => item.cost != null).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  const Text(
                    'Item Shop',
                    style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.bolt, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 2),
                  Text('$points', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: inventoryProvider.isLoading && shopItems.isEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, _) => const InventoryCardSkeleton(),
                    )
                  : shopItems.isEmpty
                      ? LeafRefreshIndicator(
                          onRefresh: () => _onRefresh(context),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              _EmptyState(errorMessage: inventoryProvider.errorMessage),
                            ],
                          ),
                        )
                      : LeafRefreshIndicator(
                          onRefresh: () => _onRefresh(context),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: shopItems.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final item = shopItems[index];
                              final canAfford = points >= (item.cost ?? 0);
                              return FadeSlideIn(
                                key: ValueKey(item.itemType),
                                delay: Duration(milliseconds: 40 * index.clamp(0, 10)),
                                child: InventoryCard(
                                  icon: item.icon,
                                  iconColor: item.accentColor,
                                  // ยังไม่มีไฟล์รูปจริงของไอเทม Energy — วางไฟล์ตามชื่อที่
                                  // InventoryItemModel.imageAsset คาดไว้ได้เลย การ์ดจะเปลี่ยนมาโชว์รูปแทน
                                  // icon เองอัตโนมัติ (ไม่มีไฟล์ก็ fallback กลับมาเป็น icon เหมือนเดิม)
                                  imageAsset: item.imageAsset,
                                  title: item.title,
                                  description: item.description,
                                  quantity: item.quantity > 0 ? item.quantity : null,
                                  actionLabel: 'Buy · ${item.cost} P',
                                  actionColor: item.accentColor,
                                  onAction: canAfford ? () => _buyItem(context, item) : null,
                                  actionBusy: inventoryProvider.busyItemType == item.itemType,
                                  celebrate: _celebratingItemType == item.itemType,
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
                failed ? Icons.cloud_off : Icons.storefront_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'No items available right now',
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
