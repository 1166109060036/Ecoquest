import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/party_model.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/constants.dart';
import '../../utils/quest_completion.dart';
import 'create_party_page.dart';

// หน้า Party — 3 สถานะ:
//  1) ยังไม่อยู่ห้องไหน -> _RoomBrowser (ลิสต์ห้องเปิดให้เข้าร่วม + ปุ่มสร้างห้องใหม่)
//  2) อยู่ในห้องที่ยัง open -> _PartyView (รายละเอียดอีเวนต์ + สมาชิก + ปุ่ม Complete/Leave)
//  3) หัวหน้ากดจบอีเวนต์แล้ว (status completed) -> แบนเนอร์สรุปรางวัล + ปุ่ม dismiss
//
// ข้อมูลจริงจาก GET /api/party (ห้องของฉัน) และ GET /api/party/rooms (ลิสต์ห้องให้เลือก)
class PartyPage extends StatefulWidget {
  // MainShell ส่ง callback นี้เข้ามาเพื่อสลับ tab ของ bottom nav (ปุ่มย้อนกลับ)
  final ValueChanged<int>? onNavigateToTab;

  const PartyPage({super.key, this.onNavigateToTab});

  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _homeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final partyProvider = context.read<PartyProvider>();
      partyProvider.loadParty();
      partyProvider.loadRooms();
    });
  }

  Future<void> _createParty() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePartyPage()),
    );
  }

  Future<void> _joinRoom(PartyRoomModel room) async {
    final partyProvider = context.read<PartyProvider>();
    final ok = await partyProvider.join(room.id);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to join this party')),
      );
    }
  }

  Future<void> _confirmLeaveParty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave party?'),
        content: const Text(
          'You will leave this event and will have to join again if you change your mind',
        ),
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

  Future<void> _confirmCompleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete this event?'),
        content: const Text(
          'Every member in this party (including you) will receive the reward. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
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
                              ? _RoomBrowser(
                                  rooms: partyProvider.rooms,
                                  isLoading: partyProvider.isLoadingRooms,
                                  errorMessage: partyProvider.roomsErrorMessage,
                                  isBusy: partyProvider.isBusy,
                                  onRefresh: partyProvider.loadRooms,
                                  onCreate: _createParty,
                                  onJoin: _joinRoom,
                                )
                              : party.isCompleted
                                  ? _CompletedView(party: party, onDismiss: _leaveParty)
                                  : _PartyView(
                                      party: party,
                                      isBusy: partyProvider.isBusy,
                                      onTapMember: _viewMemberProfile,
                                      onLeave: _confirmLeaveParty,
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
// สถานะ 1: ยังไม่อยู่ห้องไหน — ลิสต์ห้องที่เปิดรับอยู่ + ปุ่มสร้างห้องใหม่
// ---------------------------------------------------------------------------
class _RoomBrowser extends StatelessWidget {
  final List<PartyRoomModel> rooms;
  final bool isLoading;
  final String? errorMessage;
  final bool isBusy;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<PartyRoomModel> onJoin;

  const _RoomBrowser({
    required this.rooms,
    required this.isLoading,
    required this.errorMessage,
    required this.isBusy,
    required this.onRefresh,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Party', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: isLoading && rooms.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.white70))
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  color: Colors.green,
                  child: rooms.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                            _EmptyRooms(errorMessage: errorMessage),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rooms.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            return _RoomTile(
                              room: room,
                              isBusy: isBusy,
                              onJoin: () => onJoin(room),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  final String? errorMessage;
  const _EmptyRooms({this.errorMessage});

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
              size: 48,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'No party rooms open right now',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              failed ? 'Pull down to try again' : 'Be the first to create one!',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final PartyRoomModel room;
  final bool isBusy;
  final VoidCallback onJoin;

  const _RoomTile({required this.room, required this.isBusy, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(room.quest.title,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(height: 6),
                _InfoLine(icon: Icons.calendar_today_outlined, text: _formatEventDate(room.eventDate)),
                const SizedBox(height: 4),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: room.location.isEmpty ? 'Location to be announced' : room.location,
                ),
                const SizedBox(height: 4),
                _InfoLine(
                  icon: Icons.groups_outlined,
                  text: room.capacity > 0
                      ? '${room.memberCount} / ${room.capacity} joined'
                      : '${room.memberCount} joined',
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: (isBusy || room.isFull) ? null : onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              elevation: 0,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(room.isFull ? 'Full' : 'Join', style: const TextStyle(fontSize: 12)),
          ),
        ],
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
        // ---- ปุ่มด้านล่าง — เฉพาะหัวหน้ากดจบอีเวนต์ได้ สมาชิกทั่วไปแค่รอ ----
        if (party.isLeader)
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
              child: const Text('Complete Event', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  'Waiting for the leader to complete this event',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
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
// สถานะ 3: หัวหน้ากดจบอีเวนต์แล้ว — โชว์สรุปรางวัลค้างไว้ให้ทุกคนเห็นก่อน แล้วค่อยกด dismiss
// ---------------------------------------------------------------------------
class _CompletedView extends StatelessWidget {
  final PartyModel party;
  final VoidCallback onDismiss;

  const _CompletedView({required this.party, required this.onDismiss});

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
                          onTap: () {},
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
                _InfoLine(icon: Icons.calendar_today_outlined, text: _formatEventDate(party.eventDate)),
                const SizedBox(height: 6),
                _InfoLine(
                  icon: Icons.groups_outlined,
                  text: party.capacity > 0
                      ? '${party.members.length} / ${party.capacity} joined'
                      : '${party.members.length} joined',
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
