// ชิ้นส่วน UI ของหน้าโปรไฟล์ที่ใช้ซ้ำได้ ไม่ผูกกับ AuthProvider ตรงๆ (รับข้อมูลผ่าน
// constructor ล้วนๆ) — แยกออกมาจาก profile_page.dart เพื่อให้หน้าโปรไฟล์ของผู้เล่น
// คนอื่น (player_profile_page.dart) เอาไปประกอบซ้ำได้โดยไม่ต้องก๊อปโค้ด
//
// สิ่งที่ "ไม่" ย้ายมาไว้ตรงนี้ เพราะผูกกับ "ตัวเอง" เท่านั้น: _TopBar (hard-code route
// /settings, /notifications ของหน้า Profile), _AvatarSourceSheet (แก้ไขรูปได้เฉพาะตัวเอง),
// _UpgradeAbilityCard/_UpgradeRow (การ์ดซื้อของ ใช้กับตัวเองเท่านั้น)
import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../models/quest_history_model.dart';
import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// พื้นหลัง — ใส่รูปเองได้ทีหลังผ่าน AppConstants.profileBgAsset
// ถ้ายังไม่มีไฟล์รูป จะ fallback เป็น gradient สีเขียว-ฟ้าให้อัตโนมัติ ไม่มี error ค้าง
// (ตัวเดียวกับที่ party_page.dart เคยก๊อปไว้เป็น _PartyBackground แบบเหมือนทุกตัวอักษร)
// ---------------------------------------------------------------------------
class ProfileBackground extends StatelessWidget {
  const ProfileBackground({super.key});

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
// การ์ดกระจกโปร่งใสมาตรฐาน ใช้ซ้ำได้ทุกส่วนของหน้า Profile
// ---------------------------------------------------------------------------
class ProfileGlassCard extends StatelessWidget {
  final Widget child;
  const ProfileGlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// ส่วนหัว: avatar + ชื่อ + level/rank + progress bar
// ---------------------------------------------------------------------------
class UserHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl; // URL เต็มของรูปโปรไฟล์ — null = ยังไม่ได้ตั้ง
  final int level;
  final String rankTier;
  final int xp;
  final int xpToNext;
  // null = ดูโปรไฟล์คนอื่น (แก้รูปไม่ได้ ไม่โชว์ป้ายกล้อง) — มีค่าเฉพาะหน้าโปรไฟล์ตัวเอง
  final VoidCallback? onTapAvatar;

  const UserHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.rankTier,
    required this.xp,
    required this.xpToNext,
    this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final progress = xpToNext == 0 ? 0.0 : (xp / xpToNext).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarPicker(avatarUrl: avatarUrl, onTap: onTapAvatar),
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

// อวตาร 64px — แตะเพื่อเปิด bottom sheet เลือก/ลบรูป (เฉพาะตอนมี onTap)
// ป้ายกล้องเล็กๆ มุมล่างขวาโชว์เฉพาะตอนแก้ไขได้ — โปรไฟล์คนอื่นดูอย่างเดียว ไม่มีป้ายนี้
// โชว์รูปจาก avatarPath ถ้ามี (fallback เป็นไอคอนคนถ้าไฟล์หายหรือยังไม่ได้ตั้งรูป)
class _AvatarPicker extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onTap;

  const _AvatarPicker({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final editable = onTap != null;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.black.withValues(alpha: 0.48),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              // ยังไม่มีรูป หรือโหลดรูปไม่สำเร็จ (เน็ตหลุด/รูปถูกลบไปแล้ว) -> โชว์ไอคอนคนแทน
              onBackgroundImageError: avatarUrl != null ? (_, _) {} : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white70, size: 34)
                  : null,
            ),
            if (editable)
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: Colors.green,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(Icons.photo_camera, size: 13, color: Colors.white),
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
// การ์ด Point + Rank — label เปลี่ยนได้ ("Your Point" ในโปรไฟล์ตัวเอง, "Point" ในโปรไฟล์คนอื่น)
// ---------------------------------------------------------------------------
class PointsAndRankCard extends StatelessWidget {
  final int points;
  final String rankTier;
  final int rankXp; // XP ที่ไต่มาได้แล้วภายใน tier ปัจจุบัน (นับเฉพาะ season นี้)
  final int? rankXpMax; // null = อยู่ tier สูงสุดแล้ว
  final String pointsLabel;
  // null = ไม่โชว์บรรทัดซีซั่น (เผื่อโปรไฟล์เก่าที่ backend ยังไม่ส่งค่านี้มา)
  final int? seasonNumber;
  final int? seasonDaysRemaining;

  const PointsAndRankCard({
    super.key,
    required this.points,
    required this.rankTier,
    required this.rankXp,
    required this.rankXpMax,
    this.pointsLabel = 'Your Point',
    this.seasonNumber,
    this.seasonDaysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileGlassCard(
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
                    Text(pointsLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatNumber(points),
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
              // เท่ากับฝั่ง Point แล้ว (เดิม flex:2 แคบไป "Bronze Rank" ตัวหนาโดนตัดเหลือ "Bronze R...")
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black.withValues(alpha: 0.48),
                      child: const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rank',
                              style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text(
                            '$rankTier Rank',
                            // ไม่ตัดด้วย ... อีกต่อไป — ยอมให้ขึ้นบรรทัดใหม่แทน กันชื่อยศยาวๆ
                            // อย่าง "Platinum Rank" โดนตัดหายเหมือนที่ "Bronze Rank" เจอมาก่อน
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
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
                                : '${formatNumber(rankXp)} / ${formatNumber(rankXpMax!)} XP',
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                          ),
                          if (seasonNumber != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              // แยกคนละบรรทัดกัน (เดิมอยู่บรรทัดเดียวคั่นด้วย "·")
                              'Season $seasonNumber\n${seasonDaysRemaining ?? 0} days left',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 8.5,
                                height: 1.3,
                              ),
                            ),
                          ],
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
class StatsCard extends StatelessWidget {
  final ProfileStats stats;
  const StatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ProfileGlassCard(
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
                StatItem(
                  icon: Icons.eco,
                  iconColor: Colors.greenAccent,
                  value: '${stats.questCompleted.toString().padLeft(2, '0')} / '
                      '${stats.questTotal.toString().padLeft(2, '0')}',
                  label: 'Quest Completed',
                ),
                StatItem(
                  icon: Icons.cloud_outlined,
                  iconColor: Colors.lightBlueAccent,
                  value: '${stats.co2SavedKg.toStringAsFixed(1)} kgCO2e',
                  label: 'CO2 Saved',
                ),
                StatItem(
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

class StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const StatItem({
    super.key,
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
          backgroundColor: Colors.white.withValues(alpha: 0.12),
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
// การ์ด Quest History — quest ที่ทำสำเร็จไปแล้ว (ล่าสุดขึ้นก่อน)
// ---------------------------------------------------------------------------
class QuestHistoryCard extends StatelessWidget {
  final List<QuestHistoryEntry> history;
  // จำนวนแถวที่เห็นพร้อมกันโดยไม่ต้องเลื่อน — เกินจากนี้เลื่อนดูต่อได้ในกรอบเดิม ไม่ดันให้หน้า Profile
  // ยาวขึ้นเรื่อยๆ ตามจำนวนประวัติ (ก่อนหน้านี้การ์ดนี้สูงไม่จำกัด ยิ่งทำเควสเยอะหน้ายิ่งยาว)
  static const int _visibleRows = 5;
  static const double _rowHeight = 40; // เท่ากับความสูงไอคอนสี่เหลี่ยมใน QuestHistoryRow
  static const double _rowSpacing = 12;

  const QuestHistoryCard({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final maxHeight = _visibleRows * _rowHeight + (_visibleRows - 1) * _rowSpacing;

    return ProfileGlassCard(
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
              // ConstrainedBox จำกัดความสูงไว้แค่ ~5 แถว + ListView(shrinkWrap: true) ทำให้พอดีตัว
              // ถ้ามีน้อยกว่านั้น (ไม่มีที่ว่างเหลือ) และเลื่อนดูของที่เหลือได้เองถ้าเกิน
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: _rowSpacing),
                  itemBuilder: (context, index) => QuestHistoryRow(entry: history[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class QuestHistoryRow extends StatelessWidget {
  final QuestHistoryEntry entry;
  const QuestHistoryRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final visual = categoryVisual(entry.category);

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
                formatHistoryDate(entry.completedAt),
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

class CategoryVisual {
  final IconData icon;
  final Color color;
  const CategoryVisual(this.icon, this.color);
}

// map หมวดของ quest (ค่าเดียวกับ enum category ฝั่ง backend) -> ไอคอน/สี
CategoryVisual categoryVisual(String? category) {
  switch (category) {
    case 'food_waste':
      return const CategoryVisual(Icons.restaurant, Colors.orangeAccent);
    case 'recycling':
      return const CategoryVisual(Icons.recycling, Colors.greenAccent);
    case 'plastic':
      return const CategoryVisual(Icons.local_drink, Colors.lightBlueAccent);
    case 'community':
      return const CategoryVisual(Icons.groups, Colors.purpleAccent);
    case 'energy':
      return const CategoryVisual(Icons.bolt, Colors.yellowAccent);
    default:
      // quest ถูกลบไปแล้วเลยไม่รู้หมวด
      return const CategoryVisual(Icons.eco, Colors.white70);
  }
}

const monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ไม่ได้ลง package intl เลยจัดรูปแบบวันที่เอง (แบบเดียวกับที่หน้า Party ใช้)
String formatHistoryDate(DateTime date) =>
    '${monthNames[date.month - 1]} ${date.day}, ${date.year}';

String formatNumber(int n) {
  final str = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return buffer.toString();
}
