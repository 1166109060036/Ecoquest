import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/party_model.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/date_format.dart';
import '../../utils/quest_completion.dart';
import '../../widgets/profile_sections.dart';
import '../../widgets/falling_leaves_overlay.dart';
import '../../widgets/liquid_glass_dialog.dart';
import '../profile/player_profile_page.dart';

// หน้า Party — โชว์แค่ "ห้องของฉัน" เท่านั้น (ไม่มีลิสต์ห้องให้เลือกเข้าร่วมแล้ว
// ย้ายไปอยู่หน้า Explore ตอนเลือก chip "Party" แทน ดู explore_page.dart + party_room_card.dart)
// มี 2 สถานะ:
//  1) ยังไม่อยู่ห้องไหน -> _NoPartyState (พาไปหน้า Explore เพื่อหา/สร้างห้อง)
//  2) อยู่ในห้อง -> _PartyView (ยัง open) หรือ _CompletedView (หัวหน้ากดจบแล้ว)
//
// ข้อมูลจริงจาก GET /api/party
class PartyPage extends StatefulWidget {
  // MainShell ส่ง callback นี้เข้ามาเพื่อสลับ tab ของ bottom nav (ปุ่มย้อนกลับ / ไป Explore)
  final ValueChanged<int>? onNavigateToTab;

  const PartyPage({super.key, this.onNavigateToTab});

  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _homeTabIndex = 0;
  static const int _exploreTabIndex = 2;
  static const int _profileTabIndex = 4;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // เดินนาฬิกาทุก 1 วินาที — ปุ่ม Start/Complete ต้อง enable เองพอถึงเวลานัด/ครบ 15 นาที
    // โดยไม่ต้องให้ผู้ใช้ pull-to-refresh เอง (แพทเทิร์นเดียวกับ fridge_page.dart ที่นับถอยหลังของหมดอายุ)
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PartyProvider>().loadParty();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _confirmLeaveParty() async {
    final confirmed = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 28),
      title: 'Leave party?',
      content: const Text(
        'You will leave this event and will have to join again if you change your mind',
        textAlign: TextAlign.center,
        style: LiquidGlassDialog.messageStyle,
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(
          label: 'Leave Party',
          color: Colors.redAccent,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed != true || !mounted) return;
    await _leaveParty();
  }

  Future<void> _leaveParty() async {
    final partyProvider = context.read<PartyProvider>();
    final ok = await partyProvider.leave();
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to leave the party')),
      );
      return;
    }
    // กลับมาที่หน้ารายการห้อง -> รีเฟรชลิสต์ห้องให้ทันสถานะล่าสุด และรีเฟรช quest list
    // ด้วยเพราะ openPartyCount บนการ์ดใน Explore อาจเปลี่ยน (ห้องอาจถูกลบไปถ้าไม่เหลือใครแล้ว)
    if (!mounted) return;
    await Future.wait([
      partyProvider.loadRooms(),
      context.read<QuestProvider>().loadQuests(),
    ]);
  }

  // ไม่ต้องมี dialog ยืนยันเหมือน Complete เพราะ Start ไม่ได้ให้รางวัล/ย้อนกลับไม่ได้อะไร
  // แค่ปลดล็อกให้กด Complete ได้ต่อ (ยังไปต่อไม่ได้ทันทีอยู่ดี ต้องรออีก 15 นาที)
  Future<void> _startEvent() async {
    final partyProvider = context.read<PartyProvider>();
    final ok = await partyProvider.start();
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to start this event')),
      );
    }
  }

  Future<void> _confirmCompleteEvent() async {
    final confirmed = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: const Icon(Icons.task_alt_rounded, color: Colors.green, size: 30),
      title: 'Complete this event?',
      content: const Text(
        'Every member in this party (including you) will receive the reward. '
        'This cannot be undone.',
        textAlign: TextAlign.center,
        style: LiquidGlassDialog.messageStyle,
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(
          label: 'Complete',
          color: Colors.green,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    final partyProvider = context.read<PartyProvider>();
    final reward = await partyProvider.complete();

    if (!mounted) return;

    if (reward == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to complete this event')),
      );
      return;
    }

    // โชว์รางวัลของหัวหน้าเอง + รีเฟรชโปรไฟล์/เหรียญ + เด้งแสดงความยินดีถ้าได้เหรียญใหม่
    await handleQuestCompleted(context, reward);
    if (!mounted) return;
    // เควสนี้ถือว่าทำไปแล้ววันนี้ (สำหรับหัวหน้า) -> รีเฟรชให้การ์ดใน Explore/ประวัติใน Profile ตรงกัน
    final questProvider = context.read<QuestProvider>();
    await Future.wait([questProvider.loadQuests(), questProvider.loadHistory()]);
  }

  // แถวของตัวเอง -> สลับไปแท็บ Profile (ของจริง แก้ไขได้) แทนที่จะเปิดหน้าโปรไฟล์แบบดูอย่างเดียว
  // แถวของคนอื่น -> เปิดหน้าโปรไฟล์สาธารณะ (ดูอย่างเดียว) ของคนนั้น
  void _viewMemberProfile(PartyMemberModel member) {
    if (member.isMe) {
      widget.onNavigateToTab?.call(_profileTabIndex);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfilePage(userId: member.userId, displayName: member.name),
      ),
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
          const Positioned.fill(child: ProfileBackground()),
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
          const Positioned.fill(child: FallingLeavesOverlay()),
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
                                  onBrowse: () => widget.onNavigateToTab?.call(_exploreTabIndex),
                                )
                              : party.isCompleted
                                  ? _CompletedView(
                                      party: party,
                                      onTapMember: _viewMemberProfile,
                                      onDismiss: _leaveParty,
                                    )
                                  : _PartyView(
                                      party: party,
                                      isBusy: partyProvider.isBusy,
                                      now: DateTime.now(),
                                      onTapMember: _viewMemberProfile,
                                      onLeave: _confirmLeaveParty,
                                      onStart: _startEvent,
                                      onComplete: _confirmCompleteEvent,
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
// สถานะ 1: ยังไม่อยู่ห้องไหน — พาไปหน้า Explore เพื่อหา/สร้างห้อง (ไม่มีลิสต์ห้องในหน้านี้แล้ว)
// ---------------------------------------------------------------------------
class _NoPartyState extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onBrowse;

  const _NoPartyState({required this.errorMessage, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off : Icons.groups_outlined,
              size: 56,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              failed ? errorMessage! : "You're not in a party yet",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              failed ? 'Pull down to try again' : 'Browse open parties in the Explore tab',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onBrowse,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('Browse Parties', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// สถานะ 2: อยู่ในห้องที่ยัง open — การ์ดรายละเอียดอีเวนต์ -> รายชื่อสมาชิก -> ปุ่มด้านล่าง
// ---------------------------------------------------------------------------
class _PartyView extends StatelessWidget {
  final PartyModel party;
  final bool isBusy;
  final DateTime now; // ส่งเข้ามาจาก Timer.periodic ของหน้าแม่ ให้ปุ่ม/นับถอยหลัง live โดยไม่ query เวลาซ้ำ
  final ValueChanged<PartyMemberModel> onTapMember;
  final VoidCallback onLeave;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _PartyView({
    required this.party,
    required this.isBusy,
    required this.now,
    required this.onTapMember,
    required this.onLeave,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final leader = party.leader;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventCard(party: party),
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
                          onTap: () => onTapMember(leader),
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
                          // ทุกแถวกดได้เหมือนกัน ไม่ใช่แค่แถวหัวหน้า
                          showArrow: true,
                          onTap: () => onTapMember(member),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ---- ปุ่มด้านล่าง — ต้องกด Start ก่อนถึงจะกด Complete ได้ (กันปั๊มคะแนน สร้างห้องแล้วกดจบทันที) ----
        _PartyActionArea(party: party, isBusy: isBusy, now: now, onStart: onStart, onComplete: onComplete),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: isBusy ? null : onLeave,
            child: const Text('Leave Party', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// แถบปุ่มด้านล่างของ _PartyView — สลับตาม status: open (โชว์ปุ่ม Start ให้หัวหน้า) หรือ started
// (โชว์ปุ่ม Complete ให้หัวหน้า) เปิด/ปิดปุ่มเองตาม `now` ที่ Timer.periodic ของหน้าแม่ส่งเข้ามาสด
// (ค่า enable ที่แท้จริงยังเช็คซ้ำที่ backend ทุกครั้งที่กด — ตรงนี้แค่ให้ UI ตอบสนองทันทีไม่ต้องรีเฟรช)
// ---------------------------------------------------------------------------
class _PartyActionArea extends StatelessWidget {
  final PartyModel party;
  final bool isBusy;
  final DateTime now;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _PartyActionArea({
    required this.party,
    required this.isBusy,
    required this.now,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (party.isStarted) {
      final countdown = party.completeCountdownAt(now);
      final ready = countdown == null;

      if (!party.isLeader) {
        return const _WaitingPill(text: 'Event in progress — waiting for the leader to complete it');
      }
      return _GateButton(
        label: ready ? 'Complete Event' : 'Available in ${formatCountdown(countdown)}',
        enabled: ready,
        isBusy: isBusy,
        onPressed: onComplete,
      );
    }

    // party.isOpen
    final ready = party.isReadyToStartAt(now);
    if (!party.isLeader) {
      return _WaitingPill(
        text: party.memberCount < party.requiredMembers
            ? 'Waiting for more members (${party.memberCount}/${party.requiredMembers})'
            : 'Waiting for the leader to start this event',
      );
    }
    return _GateButton(
      label: ready
          ? 'Start Event'
          : party.memberCount < party.requiredMembers
              ? 'Waiting for members (${party.memberCount}/${party.requiredMembers})'
              : 'Starts ${formatEventDateTime(party.eventDate)}',
      enabled: ready,
      isBusy: isBusy,
      onPressed: onStart,
    );
  }
}

class _GateButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isBusy;
  final VoidCallback onPressed;

  const _GateButton({
    required this.label,
    required this.enabled,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (enabled && !isBusy) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
          disabledForegroundColor: Colors.white60,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _WaitingPill extends StatelessWidget {
  final String text;
  const _WaitingPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// สถานะ 3: หัวหน้ากดจบอีเวนต์แล้ว — โชว์สรุปรางวัลค้างไว้ให้ทุกคนเห็นก่อน แล้วค่อยกด dismiss
// ---------------------------------------------------------------------------
class _CompletedView extends StatelessWidget {
  final PartyModel party;
  final ValueChanged<PartyMemberModel> onTapMember;
  final VoidCallback onDismiss;

  const _CompletedView({required this.party, required this.onTapMember, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final quest = party.quest;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 40),
                      const SizedBox(height: 10),
                      const Text(
                        'Event completed!',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        party.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 14),
                _GlassCard(
                  child: Column(
                    children: [
                      for (final member in [if (party.leader != null) party.leader!, ...party.others])
                        _MemberRow(
                          member: member,
                          roleLabel: member.isLeader ? 'Party Leader' : 'Party Member',
                          showArrow: true,
                          onTap: () => onTapMember(member),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onDismiss,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Back to Parties', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดรายละเอียดอีเวนต์ของห้องนี้ — วันเวลา/สถานที่/จำนวนคนเป็นของห้อง ไม่ใช่ของ quest แล้ว
// ---------------------------------------------------------------------------
class _EventCard extends StatelessWidget {
  final PartyModel party;

  const _EventCard({required this.party});

  @override
  Widget build(BuildContext context) {
    final quest = party.quest;
    final asset = quest.coverImageAsset;

    // การ์ดนี้เป็น "รายละเอียดเควส" ต้องอ่านง่ายเป็นหลัก เลยใช้พื้นหลังทึบแทน
    // การ์ดกระจกโปร่งใสแบบ _GlassCard ที่เหลือในหน้านี้ (ตัวนั้นลอยทับรูปพื้นหลัง
    // ก็เลยทำให้ตัวหนังสือยาวๆ แบบ quest.detail อ่านยากถ้าพื้นหลังเป็นรูปสว่าง)
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16261F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // เว้นพื้นที่รูปปกเควสไว้เสมอ ไม่ว่าจะมีรูปจริงหรือยัง กันการ์ดดูโล่ง/สลับหน้าตา
          // ตอนเควสไหนมีรูปกับไม่มีรูปปนกัน
          SizedBox(
            height: 130,
            width: double.infinity,
            child: asset == null
                ? _CoverImagePlaceholder(category: quest.category)
                : Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    // ใส่ชื่อไฟล์ผิด/ไฟล์หาย -> โชว์ placeholder แทน ไม่ให้หน้าพัง
                    errorBuilder: (_, __, ___) => _CoverImagePlaceholder(category: quest.category),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.name,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  quest.title,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: party.location.isEmpty ? 'Location to be announced' : party.location,
                ),
                const SizedBox(height: 6),
                _InfoLine(icon: Icons.calendar_today_outlined, text: formatEventDateTime(party.eventDate)),
                const SizedBox(height: 6),
                _InfoLine(
                  icon: Icons.groups_outlined,
                  text: '${party.memberCount} / ${party.requiredMembers} joined',
                ),
                if (quest.detail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    quest.detail,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, height: 1.5),
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

// พื้นที่แทนรูปปกเควส ตอนยังไม่มีไฟล์รูป (หรือใส่ชื่อรูปผิด) — โชว์ไอคอนตามหมวดเควส
// แทนที่จะปล่อยว่างไปเลย ผู้ใช้จะได้รู้ว่าตรงนี้เว้นไว้สำหรับรูปปก
class _CoverImagePlaceholder extends StatelessWidget {
  final String category; // food_waste / recycling / plastic / community / energy

  const _CoverImagePlaceholder({required this.category});

  IconData get _icon {
    switch (category) {
      case 'recycling':
        return Icons.recycling;
      case 'plastic':
        return Icons.delete_outline;
      case 'energy':
        return Icons.bolt_outlined;
      case 'community':
        return Icons.groups_outlined;
      default:
        return Icons.eco_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade900, const Color(0xFF16261F)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(_icon, size: 40, color: Colors.white.withValues(alpha: 0.35)),
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// การ์ดกระจกโปร่งใส ใช้ซ้ำทั้งหน้า (สไตล์เดียวกับหน้า Profile/Settings)
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
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
              color: Colors.black.withValues(alpha: 0.38),
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
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
              backgroundColor: Colors.black.withValues(alpha: 0.48),
              backgroundImage:
                  member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
              // โหลดรูปไม่สำเร็จ (เน็ตหลุด/รูปถูกลบไปแล้ว) -> โชว์ไอคอนคนแทน ไม่ให้หน้าพัง
              onBackgroundImageError: member.avatarUrl != null ? (_, _) {} : null,
              child: member.avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white70, size: 24)
                  : null,
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
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
                          child: const Text(
                            'You',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
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
