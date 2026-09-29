import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/party_provider.dart';
import '../providers/upgrade_provider.dart';
import '../providers/auth_provider.dart';
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

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
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
    _lifecycle = AppLifecycleListener(onResume: () => _notifications.loadNotifications());
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
    });
  }

  @override
  void dispose() {
    _notifications.removeListener(_celebrateApprovals);
    _lifecycle.dispose();
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
        title: approved.count > 1 ? '${approved.count} quests approved!' : 'Quest approved!',
      );
      final questProvider = context.read<QuestProvider>();
      await Future.wait([
        context.read<AuthProvider>().refreshProfile(),
        questProvider.loadQuests(),
        questProvider.loadHistory(),
        context.read<AchievementProvider>().loadAchievements(),
      ]);
    } finally {
      _celebrating = false;
    }
  }

  void _navigateToTab(int index) => setState(() => _currentIndex = index);

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
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
      ),
    );
  }
}
