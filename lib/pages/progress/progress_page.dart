import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/party_model.dart';
import '../../models/quest_card_model.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/quest_completion.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/quest_card.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/staggered_fade_in.dart';
import '../explore/quest_detail_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      context.read<QuestProvider>().loadProgress(),
      context.read<PartyProvider>().loadParty(),
    ]);
    if (mounted) setState(() => _isLoading = false);
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
        ),
      ),
    );
  }

  Future<void> _onCompleteQuest(QuestCardModel quest) async {
    final questProvider = context.read<QuestProvider>();
    final reward = await questProvider.completeQuest(quest.id);

    if (!mounted) return;

    if (reward == null) {
      showBubbleToast(context, questProvider.errorMessage ?? 'Failed to complete quest');
      return;
    }

    // โชว์รางวัล + รีเฟรชโปรไฟล์/เหรียญ + เด้งแสดงความยินดีถ้าได้เหรียญใหม่ — เส้นทางเดียวกับ
    // ทุกที่ที่ทำ quest สำเร็จในแอพ
    await handleQuestCompleted(context, reward);
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
    final isEmpty = quests.isEmpty && party == null;

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
                            itemCount: (party != null ? 1 : 0) + quests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (party != null && index == 0) {
                                return FadeSlideIn(
                                  key: ValueKey('party-${party.id}'),
                                  child: _MyPartyCard(party: party, onTap: _openMyParty),
                                );
                              }
                              final quest = quests[party != null ? index - 1 : index];
                              return FadeSlideIn(
                                key: ValueKey(quest.id),
                                delay: Duration(milliseconds: 40 * index.clamp(0, 10)),
                                child: QuestCard(
                                  quest: quest,
                                  progressMode: true,
                                  onAction: () => _openQuestDetail(quest),
                                  onTap: () => _openQuestDetail(quest),
                                ),
                              );
                            },
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
