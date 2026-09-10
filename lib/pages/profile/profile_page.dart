import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';
import '../../services/app_photo_storage.dart';
import '../../models/profile_model.dart';
import '../../widgets/profile_sections.dart';

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

    // TODO: ยังไม่มี model/endpoint ของ upgrade ฝั่ง backend เลย ส่วนนี้เลยยัง mock อยู่
    final mockUpgrades = [
      AbilityUpgrade(
        id: 'point_booster',
        title: 'Point Booster',
        description: 'Increase point earned by 1%',
        cost: 20,
        iconKey: 'trending_up',
      ),
      AbilityUpgrade(
        id: 'quest_unlock',
        title: 'Quest Unlock',
        description: 'Unlock more quests',
        cost: 20,
        iconKey: 'lock_open',
      ),
      AbilityUpgrade(
        id: 'party_bonus',
        title: 'Party Bonus Points',
        description: 'Get 2X more bonus points in parties',
        cost: 20,
        iconKey: 'star',
      ),
      AbilityUpgrade(
        id: 'more_stamina',
        title: 'More Stamina',
        description: 'Increase stamina limit by 1',
        cost: 20,
        iconKey: 'favorite',
      ),
    ];

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
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
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
                        avatarPath: user?.avatarPath,
                        level: level,
                        rankTier: rankTier,
                        xp: xpIntoLevel,
                        xpToNext: xpForNextLevel,
                        onTapAvatar: () => _pickAvatar(context, hasAvatar: user?.avatarPath != null),
                      ),
                      const SizedBox(height: 16),
                      PointsAndRankCard(
                        points: points,
                        rankTier: rankTier,
                        rankXp: rankXpIntoTier,
                        rankXpMax: rankXpForNextTier,
                      ),
                      const SizedBox(height: 16),
                      StatsCard(stats: profileStats),
                      const SizedBox(height: 16),
                      _UpgradeAbilityCard(upgrades: mockUpgrades),
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
  // แล้วอัปเดต avatar ผ่าน AuthProvider — copy ไฟล์ไปเก็บถาวรผ่าน AppPhotoStorage ก่อน
  // (path ที่ image_picker คืนมาอยู่ใน cache เคลียร์ทิ้งได้ตลอด)
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
    // จำรูปเก่าไว้ก่อนอัปเดต เพื่อลบไฟล์ทิ้งถ้าเปลี่ยน/ลบสำเร็จ (กันไฟล์ค้าง)
    final oldAvatarPath = authProvider.user?.avatarPath;

    if (action == 'remove') {
      final ok = await authProvider.updateAvatar(null);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to remove photo')),
        );
        return;
      }
      await AppPhotoStorage.delete(oldAvatarPath);
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

      final saved = await AppPhotoStorage.save(shot.path, prefix: 'avatar');
      if (!context.mounted) return;

      final ok = await authProvider.updateAvatar(saved);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to update photo')),
        );
        // อัปโหลดไม่สำเร็จ ไฟล์ที่เพิ่ง copy ไว้ก็ไม่ต้องเก็บไว้เปล่าๆ
        await AppPhotoStorage.delete(saved);
        return;
      }
      await AppPhotoStorage.delete(oldAvatarPath);
    } catch (e) {
      if (!context.mounted) return;
      // เครื่องไม่มีกล้อง / ผู้ใช้ปฏิเสธ permission
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera')),
      );
    }
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
          onTap: () => Navigator.pushNamed(context, '/notifications'),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ด Upgrade Your Ability — list ของ upgrade พร้อมปุ่มราคา (ใช้กับตัวเองเท่านั้น
// เพราะเป็น UI ซื้อของ — โปรไฟล์ของผู้เล่นคนอื่นไม่มีการ์ดนี้)
// ---------------------------------------------------------------------------
class _UpgradeAbilityCard extends StatelessWidget {
  final List<AbilityUpgrade> upgrades;
  const _UpgradeAbilityCard({required this.upgrades});

  IconData _iconFor(String key) {
    switch (key) {
      case 'trending_up':
        return Icons.trending_up;
      case 'lock_open':
        return Icons.lock_open;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.bolt;
    }
  }

  Color _colorFor(String key) {
    switch (key) {
      case 'trending_up':
        return Colors.greenAccent;
      case 'lock_open':
        return Colors.lightBlueAccent;
      case 'star':
        return Colors.purpleAccent;
      case 'favorite':
        return Colors.pinkAccent;
      default:
        return Colors.white;
    }
  }

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
            for (final upgrade in upgrades) ...[
              _UpgradeRow(
                icon: _iconFor(upgrade.iconKey),
                iconColor: _colorFor(upgrade.iconKey),
                title: upgrade.title,
                description: upgrade.description,
                cost: upgrade.cost,
                onBuy: () {
                  // TODO: เรียก API ซื้อ upgrade จริงตอนมี endpoint
                },
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
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final int cost;
  final VoidCallback onBuy;

  const _UpgradeRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.cost,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onBuy,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 13, color: Colors.greenAccent),
              const SizedBox(width: 3),
              Text('$cost P', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
