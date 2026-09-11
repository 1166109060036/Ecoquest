import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/party_model.dart';
import '../../models/quest_card_model.dart';
import '../../providers/party_provider.dart';
import '../../providers/quest_provider.dart';
import '../../utils/party_actions.dart';
import '../../utils/quest_completion.dart';
import '../../widgets/party_room_card.dart';
import '../../widgets/quest_card.dart';
import '../inventory/fridge_page.dart';
import 'quest_detail_page.dart';

// หน้า Explore เต็มจอ — เจอได้ 2 ทาง: กด "Explore" ที่ bottom nav ตรงๆ
// หรือลากแผ่น Explore ในหน้า Home ขึ้นสุดจอ (ซึ่งจะสลับมาที่แท็บนี้)
// เหมือนกับแผ่น Explore ใน Home แต่มีพื้นที่เต็มจอ เลยเพิ่มช่องค้นหาเข้ามาด้วย
//
// chip "Party" ไม่ได้แสดง party quest template แล้ว — แสดง "ห้อง" ที่มีคนสร้างไว้จริง
// ให้กดเข้าร่วมได้เลย (ตัว quest template เจอได้เฉพาะตอนกด + สร้างห้องใหม่เท่านั้น)
class ExplorePage extends StatefulWidget {
  // MainShell ส่ง callback นี้เข้ามาเพื่อสลับ tab ของ bottom nav (พาไปแท็บ Party หลังสร้าง/เข้าร่วมห้อง)
  final ValueChanged<int>? onNavigateToTab;

  const ExplorePage({super.key, this.onNavigateToTab});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _partyTabIndex = 3;

  String _selectedFilter = 'All';
  String _searchQuery = '';
  static const _filters = ['All', 'Solo', 'Party', 'Event'];

  List<QuestCardModel> _filterQuests(List<QuestCardModel> all) {
    // party quest เป็นแค่ template สร้างห้อง — ไม่โผล่เป็นการ์ดให้กดในลิสต์นี้แล้ว
    var quests = all.where((q) => q.category != QuestCardCategory.party).toList();

    // chip "Party" มีแต่ห้อง ไม่มีเควสเดี่ยวปนอยู่
    if (_selectedFilter == 'Party') return [];

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

  List<PartyRoomModel> _filterRooms(List<PartyRoomModel> all) {
    // chip "Solo"/"Event" ไม่มีห้องปาร์ตี้ปนอยู่
    if (_selectedFilter == 'Solo' || _selectedFilter == 'Event') return [];

    var rooms = all;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      rooms = rooms
          .where((r) =>
              r.name.toLowerCase().contains(query) ||
              r.quest.title.toLowerCase().contains(query))
          .toList();
    }
    return rooms;
  }

  Future<void> _onRefresh() => Future.wait([
        context.read<QuestProvider>().loadQuests(),
        context.read<PartyProvider>().loadRooms(),
      ]);

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
    // quest ที่ต้องทำ action จริงก่อน — พาไปหน้านั้นแทนการกดจบ quest ทันที
    // (ถ้าเรียก complete ตรงนี้เลย backend จะปฏิเสธอยู่ดีเพราะยังไม่ได้ทำ action)
    if (quest.actionKey == 'fridge_check') {
      // forQuest: true เพื่อให้โชว์ปุ่ม Add Item — ทางเข้านี้คือการทำเควสจริงๆ
      // (เข้าจากหน้า Inventory จะใช้ named route '/fridge' ซึ่ง forQuest = false ดูอย่างเดียว)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FridgePage(forQuest: true)),
      );
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

  Future<void> _joinRoom(PartyRoomModel room) async {
    await joinPartyRoom(
      context,
      room,
      onJoined: () => widget.onNavigateToTab?.call(_partyTabIndex),
    );
  }

  Future<void> _createParty() async {
    final created = await Navigator.pushNamed(context, '/party/create');
    if (created == true && mounted) widget.onNavigateToTab?.call(_partyTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<QuestProvider>();
    final partyProvider = context.watch<PartyProvider>();
    final quests = _filterQuests(questProvider.quests);
    final rooms = _filterRooms(partyProvider.rooms);
    final myPartyId = partyProvider.party?.id;
    // ห้องขึ้นก่อนเควส เพราะเป็นอีเวนต์ที่มีกำหนดเวลา ส่วนเควสเดี่ยวทำเมื่อไหร่ก็ได้
    final items = <Object>[...rooms, ...quests];

    final isLoading = (questProvider.isLoading || partyProvider.isLoadingRooms) && items.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // FAB สร้างห้องปาร์ตี้ — โผล่เฉพาะตอนเลือก chip "Party" เท่านั้น
      floatingActionButton: _selectedFilter == 'Party'
          ? FloatingActionButton.extended(
              onPressed: _createParty,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Party',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
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
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : items.isEmpty
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
                                isPartyFilter: _selectedFilter == 'Party',
                                errorMessage: _selectedFilter == 'Party'
                                    ? partyProvider.roomsErrorMessage
                                    : questProvider.errorMessage,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: Colors.green,
                          child: ListView.separated(
                            // เผื่อพื้นที่ด้านล่างให้ FAB ไม่บังการ์ดใบสุดท้าย
                            padding: EdgeInsets.fromLTRB(20, 4, 20, _selectedFilter == 'Party' ? 88 : 20),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is PartyRoomModel) {
                                return PartyRoomCard(
                                  room: item,
                                  isJoined: item.id == myPartyId,
                                  onJoin: () => _joinRoom(item),
                                );
                              }
                              final quest = item as QuestCardModel;
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
  final bool isPartyFilter;
  final String? errorMessage; // โหลดไม่สำเร็จ (เน็ตหลุด/server ล่ม) — คนละเคสกับ "ไม่มีอะไรให้แสดง"

  const _EmptyState({required this.query, required this.isPartyFilter, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;

    final String message;
    final String? hint;
    if (failed) {
      message = errorMessage!;
      hint = 'Pull down to try again';
    } else if (isPartyFilter) {
      message = 'No party rooms open right now';
      hint = 'Tap + to create one';
    } else if (query.trim().isNotEmpty) {
      message = 'No quests found for "$query"';
      hint = null;
    } else {
      message = 'No quests in this category';
      hint = null;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off : (isPartyFilter ? Icons.groups_outlined : Icons.search_off),
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
