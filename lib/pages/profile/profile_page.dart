import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/constants.dart';
import '../../models/profile_model.dart';
import '../../models/quest_history_model.dart';

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
                      _TopBar(),
                      const SizedBox(height: 16),
                      _UserHeader(
                        displayName: user?.displayName ?? 'Player',
                        level: level,
                        rankTier: rankTier,
                        xp: xpIntoLevel,
                        xpToNext: xpForNextLevel,
                      ),
                      const SizedBox(height: 16),
                      _PointsAndRankCard(
                        points: points,
                        rankTier: rankTier,
                        rankXp: rankXpIntoTier,
                        rankXpMax: rankXpForNextTier,
                      ),
                      const SizedBox(height: 16),
                      _StatsCard(stats: profileStats),
                      const SizedBox(height: 16),
                      _UpgradeAbilityCard(upgrades: mockUpgrades),
                      const SizedBox(height: 16),
                      _QuestHistoryCard(history: questHistory),
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
  final int rankXp; // XP ที่ไต่มาได้แล้วภายใน tier ปัจจุบัน (นับเฉพาะ season นี้)
  final int? rankXpMax; // null = อยู่ tier สูงสุดแล้ว

  const _PointsAndRankCard({
    required this.points,
    required this.rankTier,
    required this.rankXp,
    required this.rankXpMax,
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
                    const Text('Your Point',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                            style: TextStyle(color: Colors.white70, fontSize: 16),
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
                      child: const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rank',
                              style: TextStyle(color: Colors.white54, fontSize: 10)),
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
                              // tier สูงสุดแล้ว (rankXpMax == null) -> โชว์เต็มหลอด
                              value: rankXpMax == null
                                  ? 1.0
                                  : (rankXpMax == 0 ? 0.0 : (rankXp / rankXpMax!).clamp(0.0, 1.0)),
                              minHeight: 4,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rankXpMax == null
                                ? 'MAX'
                                : '${_formatNumber(rankXp)} / ${_formatNumber(rankXpMax!)} XP',
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
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
            const Text('Stats',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.eco,
                  iconColor: Colors.greenAccent,
                  value: '${stats.questCompleted.toString().padLeft(2, '0')} / '
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
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
            backgroundColor: Colors.white.withOpacity(0.15),
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

// ---------------------------------------------------------------------------
// การ์ด Quest History — quest ที่ทำสำเร็จไปแล้ว (ล่าสุดขึ้นก่อน)
// ข้อมูลจริงจาก GET /api/quests/history
// ---------------------------------------------------------------------------
class _QuestHistoryCard extends StatelessWidget {
  final List<QuestHistoryEntry> history;
  const _QuestHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quest History',
                style: TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No quests completed yet',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              )
            else
              for (final entry in history) ...[
                _QuestHistoryRow(entry: entry),
                if (entry != history.last) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _QuestHistoryRow extends StatelessWidget {
  final QuestHistoryEntry entry;
  const _QuestHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final visual = _categoryVisual(entry.category);

    return Row(
      children: [
        // ยังไม่มีรูป quest จริงในระบบ — ใช้ไอคอนตามหมวดไปก่อน
        // ถ้าเพิ่มฟิลด์รูปใน Quest model เมื่อไหร่ ค่อยเปลี่ยนตรงนี้เป็น Image.asset/network
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: visual.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(visual.icon, color: visual.color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.questTitle,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatHistoryDate(entry.completedAt),
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '+${entry.pointsEarned} P',
          style: const TextStyle(
              color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CategoryVisual {
  final IconData icon;
  final Color color;
  const _CategoryVisual(this.icon, this.color);
}

// map หมวดของ quest (ค่าเดียวกับ enum category ฝั่ง backend) -> ไอคอน/สี
_CategoryVisual _categoryVisual(String? category) {
  switch (category) {
    case 'food_waste':
      return const _CategoryVisual(Icons.restaurant, Colors.orangeAccent);
    case 'recycling':
      return const _CategoryVisual(Icons.recycling, Colors.greenAccent);
    case 'plastic':
      return const _CategoryVisual(Icons.local_drink, Colors.lightBlueAccent);
    case 'community':
      return const _CategoryVisual(Icons.groups, Colors.purpleAccent);
    case 'energy':
      return const _CategoryVisual(Icons.bolt, Colors.yellowAccent);
    default:
      // quest ถูกลบไปแล้วเลยไม่รู้หมวด
      return const _CategoryVisual(Icons.eco, Colors.white70);
  }
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ไม่ได้ลง package intl เลยจัดรูปแบบวันที่เอง — ให้หน้าตาตรงกับ dateLabel ในการ์ด quest
String _formatHistoryDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

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
