import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/upgrade_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/profile_model.dart';
import '../../models/upgrade_model.dart';
import '../../models/inventory_item_model.dart';
import '../../widgets/profile_sections.dart';
import '../../widgets/falling_leaves_overlay.dart';

class ProfilePage extends StatelessWidget {
  // หน้า Home เอา ProfilePage ตัวนี้ไปใช้เป็นพื้นหลังด้วย ตรงนั้นต้องปิด pull-to-refresh
  // ไม่งั้นจะไปแย่ง gesture กับแผ่น Explore ที่ลากขึ้น-ลงได้
  final bool enablePullToRefresh;

  const ProfilePage({super.key, this.enablePullToRefresh = true});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final progress = authProvider.profile?.progress;
    final stats = authProvider.profile?.stats;
    // ประวัติ quest มาจาก QuestProvider (โหลดไว้แล้วตั้งแต่ MainShell) ไม่ได้ fetch ซ้ำที่นี่
    final questHistory = context.watch<QuestProvider>().history;
    final upgradeProvider = context.watch<UpgradeProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    // การ์ดร้านค้าโชว์แค่ไอเทมที่ตั้งราคาไว้ (cost != null) — starter item อย่าง Camera/Fridge ไม่ใช่ของขาย
    final shopItems = inventoryProvider.items.where((item) => item.cost != null).toList();

    // ค่าจริงจาก GET /auth/me — ระหว่างที่ยังโหลดไม่เสร็จ ใช้ค่าที่ cache ไว้ใน user ไปก่อน
    final level = progress?.level ?? user?.level ?? 1;
    final xpIntoLevel = progress?.xpIntoLevel ?? 0;
    final xpForNextLevel = progress?.xpForNextLevel ?? 0;
    final points = user?.points ?? 0;
    final rankTier = progress?.rankTier ?? user?.rank ?? 'Bronze';
    final rankXpIntoTier = progress?.rankXpIntoTier ?? 0;
    final rankXpForNextTier = progress?.rankXpForNextTier;
    final profileStats = stats ??
        ProfileStats(questCompleted: 0, questTotal: 0, co2SavedKg: 0.0, partiesJoined: 0);

    return Scaffold(
      body: Stack(
        children: [
          // ---- พื้นหลัง ----
          const Positioned.fill(child: ProfileBackground()),
          // ---- overlay มืดให้อ่านตัวหนังสือง่ายขึ้น ----
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.53),
                    Colors.black.withValues(alpha: 0.33),
                    Colors.black.withValues(alpha: 0.63),
                  ],
                ),
              ),
            ),
          ),
          // ---- ใบไม้ลอยตก ----
          const Positioned.fill(child: FallingLeavesOverlay()),
          // ---- เนื้อหา ----
          // Positioned.fill ตรงนี้สำคัญมาก: ถ้าไม่ใส่ Stack จะคำนวณขนาดตาม
          // ความสูงของเนื้อหาจริงเท่านั้น (สั้นกว่าจอ) เหลือพื้นที่ว่างสีขาว
          // (background default ของ Scaffold) โผล่ที่ด้านล่างจอ
          Positioned.fill(
            child: SafeArea(
              child: _MaybeRefreshable(
                enabled: enablePullToRefresh,
                onRefresh: () => context.read<AuthProvider>().refreshProfile(),
                child: SingleChildScrollView(
                  // ต้อง always scrollable ไม่งั้นตอนเนื้อหาสั้นกว่าจอจะดึงลง refresh ไม่ได้
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 16),
                      UserHeader(
                        displayName: user?.displayName ?? 'Player',
                        avatarUrl: user?.avatarUrl,
                        level: level,
                        rankTier: rankTier,
                        xp: xpIntoLevel,
                        xpToNext: xpForNextLevel,
                        onTapAvatar: () => _pickAvatar(context, hasAvatar: user?.avatarUrl != null),
                      ),
                      const SizedBox(height: 16),
                      PointsAndRankCard(
                        points: points,
                        rankTier: rankTier,
                        rankXp: rankXpIntoTier,
                        rankXpMax: rankXpForNextTier,
                        seasonNumber: progress?.seasonNumber,
                        seasonDaysRemaining: progress?.seasonDaysRemaining,
                      ),
                      const SizedBox(height: 16),
                      StatsCard(stats: profileStats),
                      const SizedBox(height: 16),
                      _UpgradeAbilityCard(
                        upgrades: upgradeProvider.items,
                        isBusy: upgradeProvider.isBusy,
                        points: points,
                        onBuy: (upgrade) => _buyUpgrade(context, upgrade),
                      ),
                      const SizedBox(height: 16),
                      _EnergyShopCard(
                        items: shopItems,
                        busyItemType: inventoryProvider.busyItemType,
                        points: points,
                        onBuy: (item) => _buyEnergyItem(context, item),
                      ),
                      const SizedBox(height: 16),
                      QuestHistoryCard(history: questHistory),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // เปิด bottom sheet ให้เลือกถ่ายรูป/เลือกจากคลังรูป/ลบรูป (ลบโชว์เฉพาะตอนมีรูปอยู่แล้ว)
  // แล้วอัปโหลด bytes ขึ้น server ตรงๆ ผ่าน AuthProvider — ไม่ต้องเก็บไฟล์ไว้ในเครื่องเลย
  // (ต่างจากรูปของในตู้เย็น/EcoQuest Moment ที่ยังเก็บถาวรในเครื่องผ่าน AppPhotoStorage
  // เพราะรูปโปรไฟล์อยู่บน server แล้ว ดึงกลับมาโชว์ผ่าน avatarUrl ได้เสมอไม่ว่าเครื่องไหน)
  Future<void> _pickAvatar(BuildContext context, {required bool hasAvatar}) async {
    // ใช้ String action ('camera'/'gallery'/'remove') แทน ImageSource? ตรงๆ
    // เพราะ ImageSource ไม่มีค่าให้แทนความหมาย "ลบรูป" ได้
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarSourceSheet(hasAvatar: hasAvatar),
    );

    if (action == null || !context.mounted) return;
    final authProvider = context.read<AuthProvider>();

    if (action == 'remove') {
      final ok = await authProvider.updateAvatar(null);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to remove photo')),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (shot == null || !context.mounted) return;

      final bytes = await shot.readAsBytes();
      // backend รับแค่ image/jpeg กับ image/png — เดาจากนามสกุลไฟล์ ถ้าไม่ชัวร์ให้ตกไปที่ jpeg
      // (กล้องมือถือส่วนใหญ่ถ่ายเป็น jpeg อยู่แล้ว ที่ต้องกันไว้จริงๆ คือเลือกจากแกลเลอรีที่อาจเป็น png)
      final contentType = shot.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      if (!context.mounted) return;
      final ok = await authProvider.updateAvatar(bytes, contentType: contentType);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to update photo')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      // เครื่องไม่มีกล้อง / ผู้ใช้ปฏิเสธ permission
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera')),
      );
    }
  }

  // ซื้อ upgrade 1 ระดับ — สำเร็จแล้วต้องรีเฟรชทั้งยอดแต้ม (อยู่ใน AuthProvider คนละตัว)
  // และรายการเควส (Quest Unlock เปลี่ยนจำนวนเควสที่เห็นในหน้า Explore)
  Future<void> _buyUpgrade(BuildContext context, UpgradeModel upgrade) async {
    final upgradeProvider = context.read<UpgradeProvider>();
    final ok = await upgradeProvider.buy(upgrade.upgradeType);
    if (!context.mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(upgradeProvider.errorMessage ?? 'Failed to buy this upgrade')),
      );
      return;
    }

    await Future.wait([
      context.read<AuthProvider>().refreshProfile(),
      context.read<QuestProvider>().loadQuests(),
    ]);
  }

  // ซื้อไอเทม Energy 1 ชิ้นด้วย Points — สำเร็จแล้วต้องรีเฟรชยอดแต้ม (อยู่ใน AuthProvider คนละตัว)
  // ไอเทมที่ซื้อไปจะไปโชว์ (พร้อมปุ่ม Use) ที่หน้า Inventory แทน ไม่ใช้ที่นี่เลย
  Future<void> _buyEnergyItem(BuildContext context, InventoryItemModel item) async {
    final inventoryProvider = context.read<InventoryProvider>();
    final ok = await inventoryProvider.buyItem(item.itemType);
    if (!context.mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(inventoryProvider.errorMessage ?? 'Failed to buy this item')),
      );
      return;
    }

    await context.read<AuthProvider>().refreshProfile();
  }
}

// bottom sheet เลือกที่มาของรูปโปรไฟล์ — คืนค่า 'camera' / 'gallery' / 'remove' (null = ปิดเฉยๆ)
class _AvatarSourceSheet extends StatelessWidget {
  final bool hasAvatar;
  const _AvatarSourceSheet({required this.hasAvatar});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ครอบ RefreshIndicator ให้เฉพาะตอนใช้เป็นหน้า Profile จริง
// ตอนถูกเอาไปใช้เป็นพื้นหลังของหน้า Home จะปิดไว้ กัน gesture ชนกับแผ่น Explore ที่ลากได้
// ---------------------------------------------------------------------------
class _MaybeRefreshable extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onRefresh;
  final Widget child;

  const _MaybeRefreshable({
    required this.enabled,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return RefreshIndicator(onRefresh: onRefresh, color: Colors.green, child: child);
  }
}

// ---------------------------------------------------------------------------
// แถวบนสุด: ปุ่ม Settings + ปุ่ม Notification
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    // จุดแดง = ยังมีแจ้งเตือนที่ยังไม่ได้อ่าน — หายเองตอนเปิดหน้า Notification (markAllRead)
    final hasUnread = context.watch<NotificationProvider>().unreadCount > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          icon: Icons.settings,
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
        const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        _CircleIconButton(
          icon: Icons.notifications_none_rounded,
          showBadge: hasUnread,
          onTap: () => Navigator.pushNamed(context, '/notifications'),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;
  const _CircleIconButton({required this.icon, required this.onTap, this.showBadge = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (showBadge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ด Upgrade Your Ability — list ของ upgrade พร้อมปุ่มราคา (ใช้กับตัวเองเท่านั้น
// เพราะเป็น UI ซื้อของ — โปรไฟล์ของผู้เล่นคนอื่นไม่มีการ์ดนี้) ข้อมูลจริงจาก GET /api/upgrades
// ---------------------------------------------------------------------------
class _UpgradeAbilityCard extends StatelessWidget {
  final List<UpgradeModel> upgrades;
  final bool isBusy;
  final int points; // ยอดแต้มปัจจุบัน — ใช้เช็คว่าซื้อไหวไหม
  final ValueChanged<UpgradeModel> onBuy;

  const _UpgradeAbilityCard({
    required this.upgrades,
    required this.isBusy,
    required this.points,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upgrade your Ability',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (upgrades.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No upgrades available',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              )
            else
              for (final upgrade in upgrades) ...[
                _UpgradeRow(
                  upgrade: upgrade,
                  // แต้มไม่พอ หรือกำลังซื้ออยู่ หรือเต็มระดับแล้ว = กดไม่ได้
                  isBusy: isBusy,
                  canAfford: upgrade.nextCost != null && points >= upgrade.nextCost!,
                  onBuy: () => onBuy(upgrade),
                ),
                if (upgrade != upgrades.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  final UpgradeModel upgrade;
  final bool isBusy;
  final bool canAfford;
  final VoidCallback onBuy;

  const _UpgradeRow({
    required this.upgrade,
    required this.isBusy,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final maxed = upgrade.isMaxed;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Icon(upgrade.icon, color: upgrade.color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                upgrade.title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Text(
                upgrade.description,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
              const SizedBox(height: 2),
              Text(
                'Lv. ${upgrade.level} / ${upgrade.maxLevel}',
                style: const TextStyle(color: Colors.white38, fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: (isBusy || maxed || !canAfford) ? null : onBuy,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            disabledForegroundColor: Colors.white38,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: maxed
              ? const Text('MAX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 13, color: canAfford ? Colors.greenAccent : Colors.white38),
                    const SizedBox(width: 3),
                    Text('${upgrade.nextCost} P', style: const TextStyle(fontSize: 11)),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดร้านค้าไอเทม Energy — ซื้อได้ด้วย Points ไม่จำกัดจำนวน (ต่างจาก upgrade ที่มี maxLevel)
// ข้อมูลจริงจาก GET /api/inventory (กรองเอาแค่ไอเทมที่มี cost) ใช้ provider เดียวกับหน้า Inventory
// ---------------------------------------------------------------------------
class _EnergyShopCard extends StatelessWidget {
  final List<InventoryItemModel> items;
  final String? busyItemType;
  final int points;
  final ValueChanged<InventoryItemModel> onBuy;

  const _EnergyShopCard({
    required this.items,
    required this.busyItemType,
    required this.points,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Energy Shop',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No items available',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              )
            else
              for (final item in items) ...[
                _EnergyShopRow(
                  item: item,
                  isBusy: busyItemType == item.itemType,
                  canAfford: points >= (item.cost ?? 0),
                  onBuy: () => onBuy(item),
                ),
                if (item != items.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _EnergyShopRow extends StatelessWidget {
  final InventoryItemModel item;
  final bool isBusy;
  final bool canAfford;
  final VoidCallback onBuy;

  const _EnergyShopRow({
    required this.item,
    required this.isBusy,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Icon(item.icon, color: item.accentColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Text(
                item.description,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
              if (item.quantity > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'You have ${item.quantity}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: (isBusy || !canAfford) ? null : onBuy,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            disabledForegroundColor: Colors.white38,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: isBusy
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 13, color: canAfford ? Colors.greenAccent : Colors.white38),
                    const SizedBox(width: 3),
                    Text('${item.cost} P', style: const TextStyle(fontSize: 11)),
                  ],
                ),
        ),
      ],
    );
  }
}
