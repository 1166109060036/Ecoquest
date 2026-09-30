import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/party_provider.dart';
import '../providers/upgrade_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bingo_provider.dart';
import '../widgets/reward_fly.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home/home_page.dart';
import 'inventory/inventory_page.dart';
import 'explore/explore_page.dart';
import 'community/community_page.dart';
import 'profile/profile_page.dart';

// Shell กลางที่ถือ bottom nav ไว้ตัวเดียว แล้วสลับเนื้อหาข้างในด้วย IndexedStack
// ใช้ IndexedStack แทน Navigator.push เพราะจะเก็บ state ของแต่ละ tab ไว้
// (เช่น scroll position, form ที่กรอกค้างไว้) ไม่หายตอนสลับ tab ไปมา
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  // สลับแท็บล่าง = เฟดหน้าใหม่เข้ามา + เลื่อนขึ้นนิดเดียว แทนโผล่แบบตัดฉับ (ผู้ใช้ขอให้แอพสมูทขึ้น 30 ก.ย. 2026)
  // เริ่มที่ 1 = หน้าแรกตอนเปิดแอพไม่ต้องเฟด
  late final AnimationController _tabFade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  late final Animation<double> _tabOpacity = CurvedAnimation(parent: _tabFade, curve: Curves.easeOut);
  late final Animation<Offset> _tabSlide = Tween(begin: const Offset(0, 0.015), end: Offset.zero)
      .animate(CurvedAnimation(parent: _tabFade, curve: Curves.easeOutCubic));
  // ระบบตรวจสอบภารกิจ: รางวัลมาตอนหลักฐานผ่าน (อาจเป็นตอนแอพปิดอยู่) — โหลดแจ้งเตือนใหม่ทุกครั้งที่กลับเข้าแอพ
  // แล้วฉลองของที่ผ่านใหม่ด้วยเอฟเฟครางวัลบินเข้าป้าย
  late final AppLifecycleListener _lifecycle;
  late final NotificationProvider _notifications;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _notifications = context.read<NotificationProvider>();
    _notifications.addListener(_celebrateApprovals);
    // กลับเข้าแอพ: แจ้งเตือนใหม่ (ฉลองของที่ผ่าน) + การ์ด Bingo (อาจขึ้นสัปดาห์ใหม่ระหว่างปิดแอพ)
    _lifecycle = AppLifecycleListener(onResume: () {
      _notifications.loadNotifications();
      if (mounted) context.read<BingoProvider>().loadBingo();
    });
    // โหลด quest ครั้งเดียวตรงนี้ ไม่ให้หน้า Explore กับแผ่น Explore ใน Home ต่างคนต่างยิง API
    // (ทั้งคู่อยู่ใน IndexedStack พร้อมกันตลอด ถ้าโหลดในหน้าตัวเองจะยิงซ้ำ 2 รอบ)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final questProvider = context.read<QuestProvider>();
      questProvider.loadQuests();
      questProvider.loadHistory(); // ประวัติ quest ที่โชว์ในหน้า Profile
      questProvider.loadProgress(); // เควสที่กด Start ค้างไว้ — โชว์ badge เลขที่ปุ่ม Progress
      context.read<AchievementProvider>().loadAchievements(); // เหรียญที่โชว์ในหน้า Inventory
      context.read<InventoryProvider>().loadInventory(); // ไอเทม (Camera/Fridge) ที่โชว์ในหน้า Inventory
      // ต้องโหลดตรงนี้ ไม่ใช่ในหน้า Notification เพราะจุดแดงบนกระดิ่งต้องมีเลขก่อนเปิดหน้านั้น
      context.read<NotificationProvider>().loadNotifications();
      final partyProvider = context.read<PartyProvider>();
      partyProvider.loadParty(); // ห้องที่ฉันอยู่ตอนนี้ (ถ้ามี)
      partyProvider.loadRooms(); // ลิสต์ห้องให้เลือกเข้าร่วม ตอนยังไม่มีห้อง
      context.read<UpgradeProvider>().loadUpgrades(); // การ์ด Upgrade your Ability ในหน้า Profile
      context.read<BingoProvider>().loadBingo(); // แถบ Eco Bingo บนลิสต์เควส
    });
  }

  @override
  void dispose() {
    _notifications.removeListener(_celebrateApprovals);
    _lifecycle.dispose();
    _tabFade.dispose();
    super.dispose();
  }

  // เรียกทุกครั้งที่ NotificationProvider แจ้งเปลี่ยน — มีหลักฐานผ่านใหม่ที่ยังไม่ฉลอง -> เล่นเอฟเฟค + รีเฟรชแต้ม/เควส/เหรียญ
  Future<void> _celebrateApprovals() async {
    if (_celebrating || _notifications.isLoading) return;
    _celebrating = true;
    try {
      final approved = await _notifications.takeUncelebratedApprovals();
      if (approved == null || !mounted) return;
      showRewardFly(
        context,
        points: approved.points,
        xp: approved.xp,
        title: approved.bingo
            ? 'Eco Bingo!'
            : approved.count > 1
                ? '${approved.count} quests approved!'
                : 'Quest approved!',
      );
      final questProvider = context.read<QuestProvider>();
      await Future.wait([
        context.read<AuthProvider>().refreshProfile(),
        questProvider.loadQuests(),
        questProvider.loadHistory(),
        context.read<AchievementProvider>().loadAchievements(),
        // ช่อง Bingo ของเควสที่เพิ่งผ่านติดแล้ว
        context.read<BingoProvider>().loadBingo(),
      ]);
    } finally {
      _celebrating = false;
    }
  }

  void _navigateToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // เคารพโหมดลดการเคลื่อนไหวในเครื่อง — สลับทันทีไม่เฟด
    if (MediaQuery.of(context).disableAnimations) return;
    _tabFade.forward(from: 0);
  }

  // ลำดับต้องตรงกับลำดับปุ่มใน AppBottomNavBar (Home, Inventory, Explore, Community, Profile)
  // HomePage/ExplorePage/CommunityPage ต้อง build ใหม่ทุกครั้ง (ไม่ใช่ static const) เพราะต้องส่ง
  // callback _navigateToTab เข้าไปให้ใช้สลับ tab (ลากสุดขอบ / สร้าง-เข้าร่วมห้องแล้วพาไปแท็บ Community)
  List<Widget> get _pages => [
        HomePage(onNavigateToTab: _navigateToTab),
        InventoryPage(onNavigateToTab: _navigateToTab),
        ExplorePage(onNavigateToTab: _navigateToTab),
        CommunityPage(onNavigateToTab: _navigateToTab),
        const ProfilePage(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ครอบด้วย SizedBox.expand เพราะ IndexedStack เฉยๆ บางทีไม่ยอมขยายเต็มพื้นที่
      // ที่ Scaffold.body มีให้ ทำให้เหลือช่องว่างสีขาว (background default ของ Scaffold)
      // โผล่มาระหว่างเนื้อหากับ bottomNavigationBar
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: _tabOpacity,
          child: SlideTransition(
            position: _tabSlide,
            child: IndexedStack(
              index: _currentIndex,
              // ⚠️ IndexedStack ไม่หยุดแอนิเมชันของแท็บที่ซ่อนอยู่ให้เอง (เช็คใน Flutter 3.47 แล้ว — แค่ไม่ paint)
              // แอนิเมชันวนไม่รู้จบ (ใบไม้/เอฟเฟกต์โปรไฟล์ใน Home+Profile, skeleton, ไอคอนหายใจ) เลยเดินต่อทุกเฟรม
              // ทั้งที่มองไม่เห็น = แอพสร้างเฟรมตลอดเวลาและกระตุกในแท็บที่เปิดอยู่ — TickerMode ปิด ticker ของแท็บที่ซ่อน
              // (state/ตำแหน่งเลื่อนยังอยู่ครบ กลับมาแอนิเมชันเดินต่อเอง)
              children: [
                for (final (i, page) in _pages.indexed)
                  TickerMode(enabled: i == _currentIndex, child: page),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
      ),
    );
  }
}
