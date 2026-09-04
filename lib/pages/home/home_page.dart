import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quest_card_model.dart';
import '../../widgets/quest_card.dart';
import '../profile/profile_page.dart';

// Home = หน้า Profile จริง (เต็มจอ) เป็นพื้นหลัง + แผ่น "Explore" ลอยทับด้านล่าง
// ใช้หน้า Profile ตัวจริงเป็นพื้นหลังเลย (ไม่ใช่เวอร์ชันย่อ) เพื่อให้ขนาด/หน้าตา
// ตรงกับหน้า Profile 100% — ตอนลากแผ่น Explore ลง จะเห็นหน้า Profile
// โผล่ขึ้นมาจากด้านหลังทีละนิดเป็นธรรมชาติ เพราะมันคือหน้าเดียวกันจริงๆ
//
// ลากแถบ (handle) ของแผ่น Explore — แค่ลากนิดเดียวก็สลับหน้าได้เลย ไม่ต้องลากสุดจอ:
//   - ลากขึ้นเกิน threshold (หรือสะบัดขึ้นเร็วๆ) -> ไหลขึ้นสุดจอด้วย animation แล้วค่อยสลับไปหน้า Explore
//   - ลากลงเกิน threshold (หรือสะบัดลงเร็วๆ)   -> ไหลลงสุดจอด้วย animation แล้วค่อยสลับไปหน้า Profile
//   - ลากน้อยกว่านั้น                          -> เด้งกลับตำแหน่งพัก (60% ตามดีไซน์) แบบมีสปริง
class HomePage extends StatefulWidget {
  // MainShell ส่ง callback นี้เข้ามาเพื่อสลับ tab ของ bottom nav ตอนลากถึง threshold
  final ValueChanged<int>? onNavigateToTab;

  const HomePage({super.key, this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // ตำแหน่งพัก — ล็อคตามดีไซน์ 60/40 (Explore กิน 60%, Profile โชว์ 40% ด้านบน)
  static const double _restExtent = 0.6;
  // ลากขึ้น/ลงจากตำแหน่งพักเกินระยะนี้ (สัดส่วนของความสูงจอ) ถือว่า "ตั้งใจสลับหน้า"
  // เพิ่มจากเดิมนิดหน่อยกันลากแค่เผลอมือแล้วหลุดไปหน้าอื่น
  static const double _commitDelta = 0.10;
  // ถ้าสะบัดเร็วกว่านี้ (px/s) ก็นับเป็นตั้งใจสลับหน้าเหมือนกัน แม้ลากระยะสั้น
  static const double _flingVelocity = 750;
  // ขอบเขตที่ลากได้ระหว่างลาก (กันไม่ให้ลากไปสุดขอบจนดูเวอร์เกินไประหว่างลาก)
  static const double _minDragExtent = 0.35;
  static const double _maxDragExtent = 0.9;

  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _exploreTabIndex = 2;
  static const int _profileTabIndex = 4;

  late final AnimationController _extentController;
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _extentController = AnimationController(vsync: this, value: _restExtent);
  }

  @override
  void dispose() {
    _extentController.dispose();
    super.dispose();
  }

  void _onHandleDragUpdate(DragUpdateDetails details, double screenHeight) {
    if (_isCommitting) return; // กันมือไปแตะโดนตอน animation ไหลไปสุดขอบอยู่
    final delta = details.primaryDelta! / screenHeight;
    final next = (_extentController.value - delta).clamp(
      _minDragExtent,
      _maxDragExtent,
    );
    _extentController.value = next;
  }

  void _snapBackToRest() {
    _extentController.animateTo(
      _restExtent,
      duration: const Duration(milliseconds: 420),
      // easeOutBack เด้งเลยเป้าหมายนิดนึงก่อนตั้งตัว ให้ความรู้สึกมีสปริง ไม่แข็งทื่อ
      curve: Curves.easeOutBack,
    );
  }

  // เล่น animation ให้แผ่น "ไหล" ไปสุดขอบ (บนสุด/ล่างสุด) แบบมีแรงส่งก่อน
  // เสร็จแล้วหน่วงนิดนึงให้รู้สึกว่าไปถึงจริงๆ แล้วค่อยสลับ tab
  // — สำคัญมาก: ถ้าสลับ tab ทันทีโดยไม่รอ animation จะรู้สึกกระตุกเหมือนเดิม
  Future<void> _commitTo(double targetExtent, int tabIndex) async {
    setState(() => _isCommitting = true);
    HapticFeedback.mediumImpact();
    await _extentController.animateTo(
      targetExtent,
      duration: const Duration(milliseconds: 380),
      // easeOutExpo: พุ่งไวช่วงแรกแล้วค่อยๆ หน่วงตอนใกล้ขอบ ให้ความรู้สึกมีแรงเหวี่ยง/ไหล
      // ต่างจาก easeOutCubic เดิมที่จังหวะเรียบเกินไปจนรู้สึกแข็ง
      curve: Curves.easeOutExpo,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    // หน่วงสั้นๆ ให้ตาเห็นว่า "ถึงขอบแล้วจริงๆ" ก่อนตัดสลับหน้า ไม่ใช่ตัดปุบปับทันที
    await Future.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    widget.onNavigateToTab?.call(tabIndex);
    // รีเซ็ตกลับตำแหน่งพักไว้เงียบๆ (ไม่มี animation) เพราะตอนนี้หน้าถูกซ่อนอยู่หลัง
    // IndexedStack แล้ว ผู้ใช้จะไม่เห็นการรีเซ็ตนี้ พอกลับมาหน้า Home ใหม่จะเจอตำแหน่งพักปกติ
    _extentController.value = _restExtent;
    _isCommitting = false;
  }

  void _onHandleDragEnd(DragEndDetails details) {
    if (_isCommitting) return;
    final value = _extentController.value;
    final velocityY =
        details.velocity.pixelsPerSecond.dy; // ลบ = สะบัดขึ้น, บวก = สะบัดลง

    final draggedUpEnough =
        value >= _restExtent + _commitDelta || velocityY < -_flingVelocity;
    final draggedDownEnough =
        value <= _restExtent - _commitDelta || velocityY > _flingVelocity;

    if (draggedUpEnough) {
      _commitTo(1.0, _exploreTabIndex);
    } else if (draggedDownEnough) {
      _commitTo(0.0, _profileTabIndex);
    } else {
      // ลากแค่นิดเดียว ไม่ถึงเกณฑ์ -> เด้งกลับตำแหน่งพักเสมอ
      _snapBackToRest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // ---- พื้นหลัง: หน้า Profile จริงเต็มจอ ----
          // ใช้ตัวจริงเลยแทนเวอร์ชันย่อ เพื่อให้ขนาด/สัดส่วนตรงกับหน้า Profile 100%
          // RepaintBoundary กันไม่ให้หน้า Profile ที่หนักถูกลากมา re-paint ซ้ำระหว่างลาก
          const Positioned.fill(child: RepaintBoundary(child: ProfilePage())),
          // ---- แผ่น Explore ที่ลากขึ้น-ลงได้ ----
          // AnimatedBuilder ตรงนี้คำนวณแค่ตำแหน่ง/ความสูง (ถูกมาก) ส่วน _ExploreSheet
          // ถูกส่งผ่าน `child` เข้าไปครั้งเดียว ไม่ rebuild ใหม่ทุกเฟรมตอนลาก
          AnimatedBuilder(
            animation: _extentController,
            builder: (context, child) {
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: screenHeight * _extentController.value,
                child: child!,
              );
            },
            child: RepaintBoundary(
              child: _ExploreSheet(
                quests: mockQuestCards,
                restExtent: _restExtent,
                extentController: _extentController,
                onHandleDragUpdate: (details) =>
                    _onHandleDragUpdate(details, screenHeight),
                onHandleDragEnd: _onHandleDragEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// แผ่น Explore ลอยด้านล่าง — มี handle ลากได้ + filter chips + list การ์ด quest
// ---------------------------------------------------------------------------
class _ExploreSheet extends StatefulWidget {
  final List<QuestCardModel> quests;
  final double restExtent;
  final AnimationController extentController;
  final void Function(DragUpdateDetails) onHandleDragUpdate;
  final void Function(DragEndDetails) onHandleDragEnd;

  const _ExploreSheet({
    required this.quests,
    required this.restExtent,
    required this.extentController,
    required this.onHandleDragUpdate,
    required this.onHandleDragEnd,
  });

  @override
  State<_ExploreSheet> createState() => _ExploreSheetState();
}

class _ExploreSheetState extends State<_ExploreSheet> {
  String _selectedFilter = 'All';
  static const _filters = ['All', 'Solo', 'Party', 'Event'];

  List<QuestCardModel> get _filteredQuests {
    if (_selectedFilter == 'All') return widget.quests;
    final category = QuestCardCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == _selectedFilter.toLowerCase(),
    );
    return widget.quests.where((q) => q.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder ตรงนี้ครอบแค่ Container (decoration/มุมโค้ง) เท่านั้น
    // ส่วน Column เนื้อหาข้างล่างส่งผ่าน `child` เข้ามา ถูกสร้างครั้งเดียวแล้วนำมาใช้ซ้ำ
    // ทุกเฟรมของ animation โดยไม่ rebuild ใหม่ — ลดอาการกระตุกตอนลากได้เยอะ
    return AnimatedBuilder(
      animation: widget.extentController,
      builder: (context, child) {
        final extent = widget.extentController.value;
        // มุมโค้งด้านบนค่อยๆ คลี่ตรงเป็นเหลี่ยม ตอนแผ่นใกล้เต็มจอ (extent -> 1.0)
        final unroundT =
            ((extent - widget.restExtent) / (1.0 - widget.restExtent)).clamp(
              0.0,
              1.0,
            );
        final cornerRadius = lerpDouble(24, 0, unroundT)!;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(cornerRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // ---- handle ลาก — GestureDetector ครอบเฉพาะแถบนี้ ไม่ครอบทั้ง sheet
          // เพื่อไม่ให้ชนกับการ scroll ลิสต์ quest ข้างล่าง
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: widget.onHandleDragUpdate,
            onVerticalDragEnd: widget.onHandleDragEnd,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _DragHandleBar(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore The Quests',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
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
                        onSelected: (_) =>
                            setState(() => _selectedFilter = filter),
                        selectedColor: Colors.green,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filteredQuests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final quest = _filteredQuests[index];
                return QuestCard(
                  quest: quest,
                  onAction: () {
                    // TODO: เรียก API เข้าร่วม/เริ่ม quest จริงตอนมี endpoint
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandleBar extends StatelessWidget {
  const _DragHandleBar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
