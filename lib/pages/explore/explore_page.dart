import 'package:flutter/material.dart';
import '../../models/quest_card_model.dart';
import '../../widgets/quest_card.dart';

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

  List<QuestCardModel> get _filteredQuests {
    var quests = mockQuestCards;

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

  Future<void> _onRefresh() async {
    // TODO: เรียก GET /api/quests ใหม่จริงตอนมี endpoint
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final quests = _filteredQuests;

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
              child: quests.isEmpty
                  ? _EmptyState(query: _searchQuery)
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
                            onAction: () {
                              // TODO: เรียก API เข้าร่วม/เริ่ม quest จริงตอนมี endpoint
                            },
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
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              query.trim().isEmpty ? 'ไม่มี quest ในหมวดนี้' : 'ไม่พบ quest ที่ตรงกับ "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
