import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../models/profile_model.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    // TODO: ต่อ backend endpoint จริงตอนมี API ดึงค่านี้แล้ว
    // ตอนนี้ mock ไว้ก่อนให้เห็นหน้าตาโครงสร้างครบ
    final mockLevel = 5;
    final mockXp = 320;
    final mockXpToNext = 1000;
    final mockPoints = 0;
    final mockRankTier = 'Bronze';
    final mockRankPoints = 0;
    final mockRankPointsMax = 1000;
    final mockStats = ProfileStats(
      questCompleted: 0,
      questTotal: 0,
      co2SavedKg: 0.0,
      partiesJoined: 0,
    );
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
          Positioned.fill(child: _ProfileBackground()),
          // ---- overlay มืดให้อ่านตัวหนังสือง่ายขึ้น ----
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          // ---- เนื้อหา ----
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(),
                    const SizedBox(height: 16),
                    _UserHeader(
                      displayName: user?.displayName ?? 'Player',
                      level: mockLevel,
                      rankTier: mockRankTier,
                      xp: mockXp,
                      xpToNext: mockXpToNext,
                    ),
                    const SizedBox(height: 16),
                    _PointsAndRankCard(
                      points: mockPoints,
                      rankTier: mockRankTier,
                      rankPoints: mockRankPoints,
                      rankPointsMax: mockRankPointsMax,
                    ),
                    const SizedBox(height: 16),
                    _StatsCard(stats: mockStats),
                    const SizedBox(height: 16),
                    _UpgradeAbilityCard(upgrades: mockUpgrades),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// พื้นหลัง — ใส่รูปเองได้ทีหลังผ่าน AppConstants.profileBgAsset
// ถ้ายังไม่มีไฟล์รูป จะ fallback เป็น gradient สีเขียว-ฟ้าให้อัตโนมัติ ไม่มี error ค้าง
// ---------------------------------------------------------------------------
class _ProfileBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.profileBgAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3E5C4E), Color(0xFF2C3E50)],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// แถวบนสุด: ปุ่ม Settings + ปุ่ม Notification
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          icon: Icons.settings,
          onTap: () {
            // TODO: ไปหน้า Settings
          },
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
          onTap: () {
            // TODO: ไปหน้า Notifications
          },
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
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ส่วนหัว: avatar (icon ง่ายๆ ไปก่อน) + ชื่อ + level/rank + progress bar
// ---------------------------------------------------------------------------
class _UserHeader extends StatelessWidget {
  final String displayName;
  final int level;
  final String rankTier;
  final int xp;
  final int xpToNext;

  const _UserHeader({
    required this.displayName,
    required this.level,
    required this.rankTier,
    required this.xp,
    required this.xpToNext,
  });

  @override
  Widget build(BuildContext context) {
    final progress = xpToNext == 0 ? 0.0 : (xp / xpToNext).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar placeholder — icon ง่ายๆ ไปก่อนตามที่ขอ
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.black.withOpacity(0.4),
          child: const Icon(Icons.person, color: Colors.white70, size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Lv. ${level.toString().padLeft(2, '0')}   $rankTier Rank',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$xp / $xpToNext XP',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ด "Your Point" + "Rank"
// ---------------------------------------------------------------------------
class _PointsAndRankCard extends StatelessWidget {
  final int points;
  final String rankTier;
  final int rankPoints;
  final int rankPointsMax;

  const _PointsAndRankCard({
    required this.points,
    required this.rankTier,
    required this.rankPoints,
    required this.rankPointsMax,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Point',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _formatNumber(points),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' P',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(color: Colors.white24, width: 1),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.black.withOpacity(0.4),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rank',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '$rankTier Rank',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rankPointsMax == 0
                                  ? 0
                                  : (rankPoints / rankPointsMax).clamp(
                                      0.0,
                                      1.0,
                                    ),
                              minHeight: 4,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.greenAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatNumber(rankPoints)} / ${_formatNumber(rankPointsMax)} P',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ด Stats: Quest Completed / CO2 Saved / Parties Joined
// ---------------------------------------------------------------------------
class _StatsCard extends StatelessWidget {
  final ProfileStats stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.eco,
                  iconColor: Colors.greenAccent,
                  value:
                      '${stats.questCompleted.toString().padLeft(2, '0')} / '
                      '${stats.questTotal.toString().padLeft(2, '0')}',
                  label: 'Quest Completed',
                ),
                _StatItem(
                  icon: Icons.cloud_outlined,
                  iconColor: Colors.lightBlueAccent,
                  value: '${stats.co2SavedKg.toStringAsFixed(1)} kgCO2e',
                  label: 'CO2 Saved',
                ),
                _StatItem(
                  icon: Icons.groups,
                  iconColor: Colors.orangeAccent,
                  value: stats.partiesJoined.toString().padLeft(2, '0'),
                  label: 'Parties Joined',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withOpacity(0.12),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ด Upgrade Your Ability — list ของ upgrade พร้อมปุ่มราคา
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
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upgrade your Ability',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          backgroundColor: Colors.white.withOpacity(0.12),
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
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
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
            backgroundColor: Colors.white.withOpacity(0.15),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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

// ---------------------------------------------------------------------------
// การ์ดกระจกโปร่งใสมาตรฐาน ใช้ซ้ำได้ทุกส่วนของหน้า Profile
// ---------------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

String _formatNumber(int n) {
  final str = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return buffer.toString();
}
