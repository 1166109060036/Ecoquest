import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/party_model.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/constants.dart';
import '../../utils/quest_completion.dart';

// หน้า Party — โชว์ปาร์ตี้ปัจจุบันของผู้เล่น: รายละเอียดอีเวนต์ + รายชื่อสมาชิก + ปุ่ม Leave
// ข้อมูลจริงจาก GET /api/party (เข้าร่วมได้ทีละปาร์ตี้เดียวตามดีไซน์)
// ถ้ายังไม่ได้เข้าร่วมอีเวนต์ไหน จะโชว์ empty state พร้อมปุ่มพาไปหน้า Explore
class PartyPage extends StatefulWidget {
  // MainShell ส่ง callback นี้เข้ามาเพื่อสลับ tab ของ bottom nav (ปุ่มย้อนกลับ / ปุ่ม Explore Quest)
  final ValueChanged<int>? onNavigateToTab;

  const PartyPage({super.key, this.onNavigateToTab});

  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _homeTabIndex = 0;
  static const int _exploreTabIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PartyProvider>().loadParty();
    });
  }

  Future<void> _confirmLeaveParty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave party?'),
        content: const Text(
            'You will leave this event and will have to join again if you change your mind'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave Party', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final partyProvider = context.read<PartyProvider>();
    final ok = await partyProvider.leave();
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to leave the party')),
      );
      return;
    }
    // จำนวนคนในอีเวนต์เปลี่ยน -> โหลดลิสต์ quest ใหม่ให้การ์ดใน Explore อัปเดตตาม
    await context.read<QuestProvider>().loadQuests();
  }

  // กดว่าไปร่วมอีเวนต์มาแล้ว -> รับคะแนน (backend เช็คว่าต้องเข้าร่วมก่อน และให้ทำได้ครั้งเดียว)
  Future<void> _completeEvent(PartyQuestModel quest) async {
    final questProvider = context.read<QuestProvider>();
    final reward = await questProvider.completeQuest(quest.id);

    if (!mounted) return;

    if (reward == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questProvider.errorMessage ?? 'Failed to complete this event')),
      );
      return;
    }

    await handleQuestCompleted(context, reward);
    if (!mounted) return;
    // สถานะ completed ของอีเวนต์เปลี่ยนแล้ว ต้องโหลดปาร์ตี้ใหม่
    await context.read<PartyProvider>().loadParty();
  }

  void _viewMemberProfile(String name) {
    // TODO: เปิดหน้าโปรไฟล์ของผู้เล่นคนอื่นจริงตอนมี endpoint
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$name's profile — coming soon")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partyProvider = context.watch<PartyProvider>();
    final party = partyProvider.party;

    return Scaffold(
      body: Stack(
        children: [
          // ---- พื้นหลัง: ใช้รูปเดียวกับหน้า Profile ให้ธีมไปด้วยกัน ----
          const Positioned.fill(child: _PartyBackground()),
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
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    _TopBar(onBack: () => widget.onNavigateToTab?.call(_homeTabIndex)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: partyProvider.isLoading && party == null
                          ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                          : party == null
                              ? _NoPartyState(
                                  errorMessage: partyProvider.errorMessage,
                                  onExplore: () =>
                                      widget.onNavigateToTab?.call(_exploreTabIndex),
                                )
                              : _PartyView(
                                  party: party,
                                  isBusy: partyProvider.isBusy,
                                  onTapMember: _viewMemberProfile,
                                  onLeave: _confirmLeaveParty,
                                  onComplete: () => _completeEvent(party.quest),
                                ),
                    ),
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
// เนื้อหาหลัก: การ์ดรายละเอียดอีเวนต์ -> รายชื่อสมาชิก -> ปุ่มด้านล่าง
// ---------------------------------------------------------------------------
class _PartyView extends StatelessWidget {
  final PartyModel party;
  final bool isBusy;
  final ValueChanged<String> onTapMember;
  final VoidCallback onLeave;
  final VoidCallback onComplete;

  const _PartyView({
    required this.party,
    required this.isBusy,
    required this.onTapMember,
    required this.onLeave,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final quest = party.quest;
    final leader = party.leader;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventCard(quest: quest, memberCount: party.members.length),
                const SizedBox(height: 14),
                // ---- รายชื่อสมาชิก ----
                _GlassCard(
                  child: Column(
                    children: [
                      if (leader != null) ...[
                        _MemberRow(
                          member: leader,
                          roleLabel: 'Party Leader',
                          showArrow: true,
                          onTap: () => onTapMember(leader.name),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                        ),
                      ],
                      for (final member in party.others)
                        _MemberRow(
                          member: member,
                          roleLabel: 'Party Member',
                          onTap: () => onTapMember(member.name),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ---- ปุ่มด้านล่าง ----
        if (quest.completed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.green.withValues(alpha: 0.6)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Text('Event completed',
                    style: TextStyle(
                        color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text("I joined this event",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: isBusy ? null : onLeave,
            child: const Text('Leave Party',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดรายละเอียดอีเวนต์ที่ปาร์ตี้นี้กำลังจะไปทำ
// ---------------------------------------------------------------------------
class _EventCard extends StatelessWidget {
  final PartyQuestModel quest;
  final int memberCount;

  const _EventCard({required this.quest, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final asset = quest.coverImageAsset;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asset != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: Image.asset(
                asset,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                // ยังไม่มีไฟล์รูป -> ไม่ต้องโชว์อะไร ไม่ให้หน้าพัง
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: quest.location.isEmpty ? 'Location to be announced' : quest.location,
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  icon: Icons.calendar_today_outlined,
                  text: quest.eventDate == null
                      ? 'Date to be announced'
                      : _formatEventDate(quest.eventDate!),
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  icon: Icons.groups_outlined,
                  text: quest.capacity > 0
                      ? '$memberCount / ${quest.capacity} joined'
                      : '$memberCount joined',
                ),
                if (quest.detail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    quest.detail,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75), fontSize: 12, height: 1.5),
                  ),
                ],
                const SizedBox(height: 14),
                // ---- รางวัลที่จะได้ ----
                Row(
                  children: [
                    _RewardChip(label: '+${quest.scorePoints} P', color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    _RewardChip(label: '+${quest.xpReward} XP', color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    _RewardChip(
                      label: '${quest.co2SavedKg.toStringAsFixed(1)} kg CO₂',
                      color: Colors.lightBlueAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final Color color;

  const _RewardChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ไม่ได้ลง intl เลยจัดรูปแบบเอง — เช่น "Sep 13, 2026 · 09:00"
String _formatEventDate(DateTime date) {
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}  ·  $hh:$mm';
}

// การ์ดกระจกโปร่งใส ใช้ซ้ำทั้งหน้า (สไตล์เดียวกับหน้า Profile/Settings)
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// พื้นหลัง — ใช้รูปเดียวกับ AppConstants.profileBgAsset (ไม่มีรูปก็ fallback เป็น gradient)
// ---------------------------------------------------------------------------
class _PartyBackground extends StatelessWidget {
  const _PartyBackground();

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
// แถบบนสุด: ปุ่มย้อนกลับ (ไป Home) + หัวข้อ "PARTY"
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'PARTY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // เว้นที่ว่างเท่าปุ่มย้อนกลับฝั่งซ้าย เพื่อให้หัวข้อ "PARTY" อยู่กึ่งกลางจอจริงๆ
        const SizedBox(width: 36),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final PartyMemberModel member;
  final String roleLabel;
  final bool showArrow;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.roleLabel,
    this.showArrow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: const Icon(Icons.person, color: Colors.white70, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // บอกว่าแถวไหนคือเรา จะได้หาตัวเองเจอในลิสต์ยาวๆ
                      if (member.isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('You',
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$roleLabel  ·  Lv. ${member.level.toString().padLeft(2, '0')}  ·  ${member.rank}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (showArrow) const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — ยังไม่ได้เข้าร่วมอีเวนต์ไหน พาไปหน้า Explore เพื่อหา Party Quest
// ---------------------------------------------------------------------------
class _NoPartyState extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onExplore;

  const _NoPartyState({required this.onExplore, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(failed ? Icons.cloud_off : Icons.groups_outlined,
              size: 56, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            failed ? "Couldn't load your party" : "You're not in a party yet",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              failed ? errorMessage! : 'Join a Party Quest to team up with other players',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onExplore,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Explore Quest',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
