import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/party_model.dart';
import '../../models/quest_card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/quest_completion.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/check_in_ring.dart';
import '../../widgets/proof_capture_sheet.dart';
import '../../models/submission_model.dart';
import '../../services/submission_service.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/liquid_glass_dialog.dart';
import '../inventory/fridge_page.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/quest_card.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_in.dart';
import '../explore/quest_detail_page.dart';
import '../../widgets/state_cross_fade.dart';

// หน้า Progress — เควสที่กด Start ไว้แล้วแต่ยังไม่กด Complete (ค้างได้ไม่จำกัดวัน จนกว่าจะกด
// Complete เอง) เข้าได้จากปุ่มมุมขวาบนของหน้า Explore และแผ่น Explore ในหน้า Home
//
// โชว์ห้อง party ของตัวเองไว้บนสุดด้วยถ้ามี — กดแล้วพาไปแท็บ Community เลย เพราะห้อง party มีระบบ
// start/complete ของตัวเองอยู่แล้วที่นั่น ไม่ได้ complete จากหน้านี้ (ดู PROJECT_CONTEXT.md)
//
// ใช้ Navigator.push ธรรมดาแทน named route เพราะต้องส่ง onNavigateToTab เข้าไปพาไปแท็บ Community
// (เหตุผลเดียวกับที่ explore_page.dart ใช้ MaterialPageRoute แทน named route ตอนเปิด QuestDetailPage)
class ProgressPage extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const ProgressPage({super.key, this.onNavigateToTab});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _partyTabIndex = 3;

  bool _isLoading = true;
  // หลักฐานที่ส่งไปแล้วยังรอตรวจ (ระบบตรวจสอบภารกิจ) — โชว์ใต้เควสที่กำลังทำ
  List<SubmissionModel> _pending = [];
  final _submissionService = SubmissionService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<QuestProvider>().loadProgress(),
      context.read<PartyProvider>().loadParty(),
      _loadPending(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // โหลดไม่สำเร็จก็แค่ไม่โชว์ส่วนนี้ ไม่ให้ทั้งหน้าพัง
  Future<void> _loadPending() async {
    try {
      final pending = await _submissionService.fetchMine(status: 'pending');
      if (mounted) setState(() => _pending = pending);
    } catch (_) {}
  }

  void _openQuestDetail(QuestCardModel quest) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestDetailPage(
          // เควสทุกใบในหน้านี้ start ไปแล้วทั้งหมด — ไม่มีทางกดปุ่ม Start ได้จากที่นี่
          quest: quest,
          onStart: (_) async {},
          completeMode: true,
          onComplete: _onCompleteQuest,
          heroTag: questCoverHeroTag('progress', quest.id),
        ),
      ),
    );
  }

  Future<void> _onCompleteQuest(QuestCardModel quest) async {
    final questProvider = context.read<QuestProvider>();

    // ระบบตรวจสอบภารกิจ — เควสที่ต้องมีหลักฐานต้องถ่ายรูปก่อน (Check Food ไม่ต้อง ระบบตรวจจากตู้เย็นเอง)
    ProofPhoto? proof;
    if (quest.requiresProof) {
      proof = await showProofCaptureSheet(
        context,
        title: quest.isMultiDay ? 'Check in with a photo' : 'Show that you did it',
        hint: quest.detail.isNotEmpty ? quest.detail : 'Take a clear photo that shows you completed "${quest.title}".',
      );
      if (proof == null || !mounted) return;
    }

    final reward = await questProvider.completeQuest(
      quest.id,
      photoBytes: proof?.bytes,
      photoContentType: proof?.contentType,
    );

    if (!mounted) return;

    if (reward == null) {
      // เควสตู้เย็นที่ยังไม่ได้บันทึกของวันนี้ — แทนที่จะโชว์ toast เฉยๆ ให้มีทางไปหน้าตู้เย็นต่อได้เลย
      final error = questProvider.errorMessage ?? '';
      if (quest.actionKey == 'fridge_check' && error.toLowerCase().contains('fridge')) {
        await _showFridgeFirstDialog(quest);
        return;
      }
      showBubbleToast(context, error.isNotEmpty ? error : 'Failed to complete quest');
      return;
    }

    // เควสหลายวันที่ยังไม่ครบ = แค่เช็คอิน ไม่ได้แต้ม — ห้ามเรียก handleQuestCompleted (จะเด้ง "+0 points")
    // การ์ดฉลองวงแหวนเช็คอินแทน bubble toast เดิม (ดู widgets/check_in_ring.dart)
    if (reward.isCheckInOnly) {
      final checkIn = reward.checkIn!;
      // เช็คอินนับ Daily Streak ด้วย — รีเฟรชโปรไฟล์ให้ตัวเลข streak ขยับ
      context.read<AuthProvider>().refreshProfile();
      _loadPending();
      await showCheckInCelebration(
        context,
        daysDone: checkIn.daysDone,
        total: checkIn.durationDays,
        restarted: checkIn.restarted,
        pending: reward.isPending,
      );
      return;
    }

    // ส่งหลักฐานไปรอตรวจ — ยังไม่ได้แต้ม ห้ามเรียก handleQuestCompleted (จะเด้ง "+0 points") รางวัลมาตอนผ่าน
    // ผ่านแจ้งเตือน quest_approved (main_shell.dart เล่นเอฟเฟครางวัลให้ตอนนั้น)
    if (reward.isPending) {
      context.read<AuthProvider>().refreshProfile(); // streak นับตั้งแต่ตอนส่ง
      _loadPending();
      final checkIn = reward.checkIn;
      if (checkIn != null && checkIn.finished) {
        await showCheckInCelebration(
          context,
          daysDone: checkIn.durationDays,
          total: checkIn.durationDays,
          finished: true,
          pending: true,
        );
      } else {
        showBubbleToast(context, 'Sent for review — you get +${quest.pointsReward} P once it is approved');
      }
      return;
    }

    // วันสุดท้ายของเควสหลายวัน — โชว์วงแหวนเติมจนครบ + เรืองแสงก่อน แล้วค่อยไปรางวัลตามปกติ
    final checkIn = reward.checkIn;
    if (checkIn != null && checkIn.finished) {
      await showCheckInCelebration(
        context,
        daysDone: checkIn.durationDays,
        total: checkIn.durationDays,
        finished: true,
      );
      if (!mounted) return;
    }

    // โชว์รางวัล + รีเฟรชโปรไฟล์/เหรียญ + เด้งแสดงความยินดีถ้าได้เหรียญใหม่ — เส้นทางเดียวกับ
    // ทุกที่ที่ทำ quest สำเร็จในแอพ
    await handleQuestCompleted(context, reward);
  }

  Future<void> _showFridgeFirstDialog(QuestCardModel quest) async {
    final openFridge = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: const Icon(Icons.kitchen_rounded, color: Colors.greenAccent, size: 30),
      title: 'Add your fridge items first',
      content: const Text(
        'Save at least one item with its expiration date today, then complete the quest.',
        textAlign: TextAlign.center,
        style: LiquidGlassDialog.messageStyle,
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(label: 'Open Fridge', color: Colors.green, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (openFridge != true || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FridgePage(forQuest: true, quest: quest)),
    );
  }

  void _openMyParty() {
    Navigator.pop(context);
    widget.onNavigateToTab?.call(_partyTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<QuestProvider>();
    final partyProvider = context.watch<PartyProvider>();
    final quests = questProvider.inProgress;
    final party = partyProvider.party;
    final isEmpty = quests.isEmpty && party == null && _pending.isEmpty;

    // ลิสต์แบนๆ: ห้อง party (ถ้ามี) -> เควสที่กำลังทำ -> หัวข้อ + หลักฐานที่รอตรวจ
    final items = <Widget>[
      if (party != null)
        FadeSlideIn(
          key: ValueKey('party-${party.id}'),
          child: _MyPartyCard(party: party, onTap: _openMyParty),
        ),
      for (var i = 0; i < quests.length; i++)
        FadeSlideIn(
          key: ValueKey(quests[i].id),
          delay: Duration(milliseconds: 40 * (i + (party != null ? 1 : 0)).clamp(0, 10)),
          child: QuestCard(
            quest: quests[i],
            progressMode: true,
            onAction: () => _openQuestDetail(quests[i]),
            onTap: () => _openQuestDetail(quests[i]),
            heroTag: questCoverHeroTag('progress', quests[i].id),
          ),
        ),
      if (_pending.isNotEmpty) const _SectionHeader(text: 'Waiting for review'),
      for (final s in _pending) _PendingSubmissionTile(submission: s),
    ];

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
                    'Progress',
                    style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StateCrossFade(
                stateKey: _isLoading ? 'loading' : isEmpty ? 'empty' : 'list',
                child: _isLoading
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: 4,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, _) => const QuestCardSkeleton(),
                      )
                    : isEmpty
                        ? LeafRefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                const _EmptyState(),
                              ],
                            ),
                          )
                        : LeafRefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => items[index],
                            ),
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
// หลักฐานที่ส่งไปแล้วรอตรวจ — รูปย่อ + ชื่อเควส + ความคืบหน้าการตรวจ (ระบบตรวจสอบภารกิจ)
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _PendingSubmissionTile extends StatelessWidget {
  final SubmissionModel submission;
  const _PendingSubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final title = s.quest?.title ?? 'Quest';
    final subtitle = s.isParty
        ? 'Group photo'
        : s.isCheckIn
            ? 'Day ${s.checkInDay}/${s.checkInTotal} check-in'
            : 'Proof photo';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              s.photoUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade200,
                child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      s.escalated ? Icons.admin_panel_settings_rounded : Icons.hourglass_top_rounded,
                      size: 13,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      // ค้างเกิน 48 ชม. = ส่งต่อให้แอดมินตัดสิน
                      s.escalated ? 'Waiting for an admin' : 'Approved ${s.approvals}/${s.approvalsNeeded}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
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

// ---------------------------------------------------------------------------
// การ์ดห้อง party ของตัวเอง — กดแล้วพาไปแท็บ Community ตรงๆ ไม่ได้ complete จากที่นี่
// (คนละ widget กับ PartyRoomCard เพราะนั่นออกแบบไว้สำหรับห้องที่ "ยังไม่ได้เข้าร่วม" ในลิสต์ Explore)
// ---------------------------------------------------------------------------
class _MyPartyCard extends StatelessWidget {
  final PartyModel party;
  final VoidCallback onTap;

  const _MyPartyCard({required this.party, required this.onTap});

  String get _statusLabel {
    switch (party.status) {
      case 'started':
        return 'In progress';
      case 'reviewing':
        return 'Waiting for review';
      case 'completed':
        return 'Completed';
      default:
        return 'Open';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepOrange.withValues(alpha: 0.12),
                child: const Icon(Icons.groups_rounded, color: Colors.deepOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      party.quest.title,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathingIcon(
              child: Icon(Icons.checklist_rounded, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Text(
              'No quests in progress',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Start one from Explore',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
