import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/quest_card_model.dart';
import '../../utils/quest_completion.dart';
import '../../providers/quest_provider.dart';
import '../../widgets/quest_card.dart';
import 'quest_detail_page.dart';

// หน้า Explore เต็มจอ — เจอได้ 2 ทาง: กด "Explore" ที่ bottom nav ตรงๆ
// หรือลากแผ่น Explore ในหน้า Home ขึ้นสุดจอ (ซึ่งจะสลับมาที่แท็บนี้)
// เหมือนกับแผ่น Explore ใน Home แต่มีพื้นที่เต็มจอ เลยเพิ่มช่องค้นหาเข้ามาด้วย
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  static const _filters = ['All', 'Solo', 'Party', 'Event'];

  List<QuestCardModel> _filterQuests(List<QuestCardModel> all) {
    var quests = all;

    if (_selectedFilter != 'All') {
      final category = QuestCardCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == _selectedFilter.toLowerCase(),
      );
      quests = quests.where((q) => q.category == category).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      quests = quests
          .where((q) =>
              q.title.toLowerCase().contains(query) ||
              q.subtitle.toLowerCase().contains(query))
          .toList();
    }

    return quests;
  }

  Future<void> _onRefresh() => context.read<QuestProvider>().loadQuests();

  // ใช้ MaterialPageRoute แทน named route เพราะต้องส่ง object quest เข้าไปทั้งก้อน
  // (ถ้าใช้ named route ต้องยัดผ่าน settings.arguments แล้ว cast เอง ซึ่งพังง่ายกว่า)
  void _openQuestDetail(QuestCardModel quest) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestDetailPage(quest: quest, onStart: _onStartQuest),
      ),
    );
  }

  Future<void> _onStartQuest(QuestCardModel quest) async {
    // party quest: ปุ่มคือ "Join" — เข้าร่วมอีเวนต์ก่อน แล้วค่อยไปกดสำเร็จที่หน้า Party
    if (quest.category == QuestCardCategory.party) {
      await joinPartyQuest(context, quest);
      return;
    }

    // quest ที่ต้องทำ action จริงก่อน — พาไปหน้านั้นแทนการกดจบ quest ทันที
    // (ถ้าเรียก complete ตรงนี้เลย backend จะปฏิเสธอยู่ดีเพราะยังไม่ได้ทำ action)
    if (quest.actionKey == 'fridge_check') {
      Navigator.pushNamed(context, '/fridge');
      return;
    }

    final questProvider = context.read<QuestProvider>();

    final reward = await questProvider.completeQuest(quest.id);

    if (!mounted) return;

    if (reward == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questProvider.errorMessage ?? 'Failed to complete quest')),
      );
      return;
    }

    // โชว์รางวัล + รีเฟรชโปรไฟล์/เหรียญ + เด้งแสดงความยินดีถ้าได้เหรียญใหม่
    await handleQuestCompleted(context, reward);
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<QuestProvider>();
    final quests = _filterQuests(questProvider.quests);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explore',
                      style: TextStyle(color: Colors.green, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Explore The Quests', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 14),
                  // ---- ช่องค้นหา — เพิ่มเข้ามาเพราะหน้าเต็มจอมีพื้นที่พอ ----
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search quests...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = filter == _selectedFilter;
                        return ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedFilter = filter),
                          selectedColor: Colors.green,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? Colors.green : Colors.grey.shade300),
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: questProvider.isLoading && questProvider.quests.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : quests.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: Colors.green,
                          // ต้องเป็น scrollable ไม่งั้นลิสต์ว่างจะดึงลง refresh ไม่ได้
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              _EmptyState(
                                query: _searchQuery,
                                errorMessage: questProvider.errorMessage,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: Colors.green,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: quests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final quest = quests[index];
                              return QuestCard(
                                quest: quest,
                                onAction: () => _onStartQuest(quest),
                                onTap: () => _openQuestDetail(quest),
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

class _EmptyState extends StatelessWidget {
  final String query;
  final String? errorMessage; // โหลด quest ไม่สำเร็จ (เน็ตหลุด/server ล่ม) — คนละเคสกับ "ไม่มี quest"

  const _EmptyState({required this.query, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off : Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              failed
                  ? errorMessage!
                  : query.trim().isEmpty
                      ? 'No quests in this category'
                      : 'No quests found for "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (failed) ...[
              const SizedBox(height: 6),
              Text(
                'Pull down to try again',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
