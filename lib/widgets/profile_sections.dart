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
import '../utils/cosmetics.dart';
import 'count_up_text.dart';
import 'decorated_avatar.dart';
import 'liquid_glass_dialog.dart';

// ---------------------------------------------------------------------------
// พื้นหลัง — ใส่รูปเองได้ทีหลังผ่าน AppConstants.profileBgAsset
// ถ้ายังไม่มีไฟล์รูป จะ fallback เป็น gradient สีเขียว-ฟ้าให้อัตโนมัติ ไม่มี error ค้าง
// (ตัวเดียวกับที่ party_page.dart เคยก๊อปไว้เป็น _PartyBackground แบบเหมือนทุกตัวอักษร)
//
// backgroundItemType (จาก EquippedCosmetics.background) มีค่า = ใส่พื้นหลังที่ซื้อไว้อยู่แทน
// ค่าเริ่มต้น — ⚠️ widget นี้เป็นฉากหลังของหน้า Home ด้วย (ดู home_page.dart ที่ใช้ ProfilePage
// เป็นพื้นหลังเต็มจอ) ซื้อพื้นหลังแล้วหน้า Home จะเปลี่ยนตามไปด้วย ตั้งใจให้เป็นแบบนั้น
// ---------------------------------------------------------------------------
class ProfileBackground extends StatelessWidget {
  final String? backgroundItemType;

  const ProfileBackground({super.key, this.backgroundItemType});

  @override
  Widget build(BuildContext context) {
    final style = cosmeticStyleFor(backgroundItemType);

    if (style?.backgroundGradient != null) {
      return Container(decoration: BoxDecoration(gradient: style!.backgroundGradient));
    }

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
// ส่วนหัว: avatar + ชื่อ + level + progress bar
// ---------------------------------------------------------------------------
class UserHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl; // URL เต็มของรูปโปรไฟล์ — null = ยังไม่ได้ตั้ง
  // itemType ของกรอบ/สีชื่อที่ใส่อยู่ (จาก EquippedCosmetics) — null = ไม่ได้ใส่ ใช้ค่าเริ่มต้นเดิม
  final String? frameItemType;
  final String? nameStyleItemType;
  final int level;
  final int xp;
  final int xpToNext;
  // null = ดูโปรไฟล์คนอื่น (แก้รูปไม่ได้ ไม่โชว์ป้ายกล้อง) — มีค่าเฉพาะหน้าโปรไฟล์ตัวเอง
  final VoidCallback? onTapAvatar;

  const UserHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.frameItemType,
    this.nameStyleItemType,
    required this.level,
    required this.xp,
    required this.xpToNext,
    this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final progress = xpToNext == 0 ? 0.0 : (xp / xpToNext).clamp(0.0, 1.0);
    final nameStyle = cosmeticStyleFor(nameStyleItemType);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedAvatar(
          avatarUrl: avatarUrl,
          size: 64,
          frameItemType: frameItemType,
          showCameraBadge: onTapAvatar != null,
          onTap: onTapAvatar,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              nameStyle?.nameGradient != null
                  ? ShaderMask(
                      shaderCallback: (bounds) => nameStyle.nameGradient!.createShader(bounds),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: nameStyle!.nameGlow,
                        ),
                      ),
                    )
                  : Text(
                      displayName,
                      style: TextStyle(
                        color: nameStyle?.nameColor ?? Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: nameStyle?.nameGlow,
                      ),
                    ),
              const SizedBox(height: 2),
              Text(
                'Lv. ${level.toString().padLeft(2, '0')}',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUpNumber(
                    value: xp,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(' / $xpToNext XP', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ด Point + Daily Streak — label เปลี่ยนได้ ("Your Point" ในโปรไฟล์ตัวเอง, "Point" ในโปรไฟล์คนอื่น)
// ---------------------------------------------------------------------------
class StreakCard extends StatelessWidget {
  final int points;
  final StreakInfo streak;
  final String pointsLabel;

  const StreakCard({
    super.key,
    required this.points,
    required this.streak,
    this.pointsLabel = 'Your Point',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // กดฝั่งไหนของการ์ดก็เปิดรายละเอียด Streak ได้เหมือนกัน (ฝั่ง Point ไม่มีอะไรให้ดูเพิ่มอยู่แล้ว)
        onTap: () => _showStreakDetail(context, streak),
        child: ProfileGlassCard(
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CountUpNumber(
                              value: points,
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const Text(' P', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(color: Colors.white24, width: 1),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black.withValues(alpha: 0.48),
                          child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daily Streak',
                                  style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text(
                                'Day ${streak.count} / ${streak.cycleLength}',
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
                                  // ไม่มี milestone ถัดไปแล้ว (ไม่ควรเกิดจริง) -> โชว์เต็มหลอดไปเลย
                                  value: streak.nextMilestone == null
                                      ? 1.0
                                      : (streak.count / streak.nextMilestone!).clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                streak.nextMilestone == null
                                    ? 'MAX'
                                    : 'Next: Day ${streak.nextMilestone}',
                                style: const TextStyle(color: Colors.white54, fontSize: 9),
                              ),
                              if (streak.nextReward != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '+${formatNumber(streak.nextReward!.points)}P '
                                  '+${formatNumber(streak.nextReward!.xp)}XP'
                                  '${streak.nextReward!.itemType != null ? ' + item' : ''}',
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
                        Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// เปิดดูรายละเอียด Daily Streak เต็มๆ — ตาราง 30 วัน + รางวัลของทุก milestone ผ่านแล้ว/ยัง
// เรียกจาก StreakCard เอง (self-contained ไม่ต้องส่ง callback ผ่าน constructor) ทั้งหน้า Profile
// ตัวเองและหน้าโปรไฟล์คนอื่นที่ใช้ StreakCard ตัวเดียวกันเลยได้ฟีเจอร์นี้ฟรีทั้งคู่
void _showStreakDetail(BuildContext context, StreakInfo streak) {
  LiquidGlassDialog.show<void>(
    context: context,
    icon: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 36),
    title: 'Daily Streak',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Day ${streak.count} / ${streak.cycleLength}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete at least 1 quest a day to keep your streak going. '
          'Miss a day and it resets back to Day 1.',
          textAlign: TextAlign.center,
          style: LiquidGlassDialog.messageStyle,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (int day = 1; day <= streak.cycleLength; day++)
              _StreakDayDot(day: day, achieved: day <= streak.count, isMilestone: streak.milestones.contains(day)),
          ],
        ),
        const SizedBox(height: 16),
        for (final day in streak.milestones) _StreakRewardRow(day: day, streak: streak),
      ],
    ),
    actions: [
      LiquidGlassAction(label: 'Got it', color: Colors.orange, onPressed: () => Navigator.pop(context)),
    ],
  );
}

// จุดวันเดียว 1-30 ในตาราง — milestone (7/14/21/30) ตัวใหญ่กว่า+มีไอคอนของขวัญทับ ให้แยกจากวันธรรมดาชัดๆ
class _StreakDayDot extends StatelessWidget {
  final int day;
  final bool achieved;
  final bool isMilestone;

  const _StreakDayDot({required this.day, required this.achieved, required this.isMilestone});

  @override
  Widget build(BuildContext context) {
    final size = isMilestone ? 26.0 : 20.0;
    final color = achieved
        ? (isMilestone ? Colors.orangeAccent : Colors.orangeAccent.withValues(alpha: 0.8))
        : Colors.white.withValues(alpha: 0.08);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isMilestone
            ? Border.all(color: Colors.white.withValues(alpha: achieved ? 0.9 : 0.3), width: 1.4)
            : null,
      ),
      child: isMilestone
          ? Icon(Icons.card_giftcard, size: 13, color: achieved ? Colors.white : Colors.white38)
          : Text(
              '$day',
              style: TextStyle(
                fontSize: 8,
                color: achieved ? Colors.black87 : Colors.white38,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

// แถวรางวัลของ milestone หนึ่งวัน — เครื่องหมายถูกสีเขียวถ้าผ่านไปแล้วในรอบนี้
class _StreakRewardRow extends StatelessWidget {
  final int day;
  final StreakInfo streak;

  const _StreakRewardRow({required this.day, required this.streak});

  @override
  Widget build(BuildContext context) {
    final reward = streak.rewards[day];
    final achieved = day <= streak.count;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            achieved ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: achieved ? Colors.greenAccent : Colors.white30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reward == null
                  ? 'Day $day'
                  : 'Day $day — +${formatNumber(reward.points)}P +${formatNumber(reward.xp)}XP'
                      '${reward.itemType != null ? ' + item' : ''}',
              style: TextStyle(
                color: achieved ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: achieved ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
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
                  // ยอดรวมทุกครั้งที่ทำเควสสำเร็จ (นับเควสซ้ำด้วย) ไม่มี "/ ทั้งหมด" แล้ว เพราะเควส
                  // รายวันทำซ้ำได้ไม่จำกัด ไม่มีเลข "ทั้งหมด" ที่ตายตัวให้เทียบ (เหมือน Parties Joined)
                  value: stats.questCompleted.toString().padLeft(2, '0'),
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
