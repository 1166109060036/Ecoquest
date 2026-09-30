import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bingo_model.dart';
import '../../models/quest_card_model.dart';
import '../../providers/bingo_provider.dart';
import '../../providers/quest_provider.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/leaf_refresh_indicator.dart';
import '../../widgets/pressable_scale.dart';
import '../explore/quest_detail_page.dart';

// หน้า Eco Bingo รายสัปดาห์ (backend/utils/bingo.js) — อาจารย์อยากให้ "อยากทำเควสต่อไปเรื่อยๆ" (30 ก.ย. 2026)
// การ์ด 3x3 ช่องกลางฟรี / ช่องติดเมื่อเควสผ่านการตรวจ / ครบแถวได้โบนัสเองอัตโนมัติ (แจ้งเตือน + เอฟเฟครางวัลที่ main_shell)
// แตะช่องที่ยังไม่ทำ = เปิดรายละเอียดเควสนั้นให้กด Start ต่อได้เลย (onStartQuest มาจากหน้าที่เปิด — Explore/Home)
class BingoPage extends StatefulWidget {
  final Future<void> Function(QuestCardModel quest) onStartQuest;

  const BingoPage({super.key, required this.onStartQuest});

  @override
  State<BingoPage> createState() => _BingoPageState();
}

class _BingoPageState extends State<BingoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BingoProvider>().loadBingo();
    });
  }

  void _openCell(BingoCell cell) {
    if (cell.free) return;
    if (cell.done) {
      showBubbleToast(context, 'Done this week — nice!');
      return;
    }
    if (cell.pending) {
      showBubbleToast(context, 'Waiting for review — this tile fills in once it is approved');
      return;
    }
    final quests = context.read<QuestProvider>().quests;
    final quest = quests.where((q) => q.id == cell.questId).firstOrNull;
    if (quest == null) {
      showBubbleToast(context, 'This quest is not available right now');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuestDetailPage(quest: quest, onStart: widget.onStartQuest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BingoProvider>();
    final card = provider.card;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Eco Bingo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ),
      body: SafeArea(
        child: card == null
            ? Center(
                child: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.green)
                    : Text(provider.errorMessage ?? 'Could not load Eco Bingo',
                        style: TextStyle(color: Colors.grey.shade600)),
              )
            : LeafRefreshIndicator(
                onRefresh: () => context.read<BingoProvider>().loadBingo(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _BingoHeader(card: card),
                    const SizedBox(height: 16),
                    _BingoGrid(card: card, onTap: _openCell),
                    const SizedBox(height: 14),
                    Text(
                      'Tiles fill in once your proof is approved. Complete a row, column or diagonal for a bonus — '
                      'the free tile in the middle counts for everyone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BingoHeader extends StatelessWidget {
  final BingoCardModel card;
  const _BingoHeader({required this.card});

  String get _endsIn {
    final left = card.weekEndsAt.difference(DateTime.now());
    if (left.inDays >= 1) return 'New card in ${left.inDays} day${left.inDays == 1 ? '' : 's'}';
    if (left.inHours >= 1) return 'New card in ${left.inHours} h';
    return 'New card soon';
  }

  @override
  Widget build(BuildContext context) {
    final lines = card.completeLines.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_on_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('This week\'s card',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              Text(_endsIn, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.full ? 'Full card complete!' : '${card.doneCount}/${card.questCount} quests · $lines line${lines == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '+${card.linePoints} P per line · +${card.fullPoints} P for the full card',
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _BingoGrid extends StatelessWidget {
  final BingoCardModel card;
  final void Function(BingoCell cell) onTap;
  const _BingoGrid({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inLine = card.cellsInCompleteLines;
    final almost = card.almostCells;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final cell in card.cells)
          _BingoTile(
            cell: cell,
            inCompleteLine: inLine.contains(cell.index),
            almost: almost.contains(cell.index),
            onTap: () => onTap(cell),
          ),
      ],
    );
  }
}

class _BingoTile extends StatelessWidget {
  final BingoCell cell;
  final bool inCompleteLine;
  final bool almost; // ขาดช่องนี้ช่องเดียวก็ครบแถว
  final VoidCallback onTap;
  const _BingoTile({required this.cell, required this.inCompleteLine, required this.almost, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = inCompleteLine
        ? Colors.amber.shade600
        : almost
            ? Colors.orange.shade300
            : Colors.grey.shade300;
    final cover = cell.coverImageAsset;
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: inCompleteLine ? 3 : 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: cell.free
              ? Container(
                  color: Colors.green.shade50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.eco_rounded, color: Colors.green.shade600, size: 30),
                      const SizedBox(height: 2),
                      Text('FREE',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null)
                      Image.asset(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                    else
                      Container(color: Colors.grey.shade100),
                    // ไล่สีเข้มด้านล่างให้ชื่อเควสอ่านออกบนรูป
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: Text(
                        cell.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.15),
                      ),
                    ),
                    if (cell.done)
                      Container(
                        color: Colors.green.withValues(alpha: 0.55),
                        child: const Center(child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 38)),
                      ),
                    if (cell.pending)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.orange.shade700),
                        ),
                      ),
                    if (almost && !cell.done && !cell.pending)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('1 more!',
                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
