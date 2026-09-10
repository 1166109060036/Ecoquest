import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quest_provider.dart';
import '../providers/achievement_provider.dart';
import '../providers/party_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home/home_page.dart';
import 'inventory/inventory_page.dart';
import 'explore/explore_page.dart';
import 'party/party_page.dart';
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

  @override
  void initState() {
    super.initState();
    // โหลด quest ครั้งเดียวตรงนี้ ไม่ให้หน้า Explore กับแผ่น Explore ใน Home ต่างคนต่างยิง API
    // (ทั้งคู่อยู่ใน IndexedStack พร้อมกันตลอด ถ้าโหลดในหน้าตัวเองจะยิงซ้ำ 2 รอบ)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final questProvider = context.read<QuestProvider>();
      questProvider.loadQuests();
      questProvider.loadHistory(); // ประวัติ quest ที่โชว์ในหน้า Profile
      context.read<AchievementProvider>().loadAchievements(); // เหรียญที่โชว์ในหน้า Inventory
      context.read<PartyProvider>().loadParty(); // ปาร์ตี้ที่โชว์ในหน้า Party
    });
  }

  void _navigateToTab(int index) => setState(() => _currentIndex = index);

  // ลำดับต้องตรงกับลำดับปุ่มใน AppBottomNavBar (Home, Inventory, Explore, Party, Profile)
  // HomePage ต้อง build ใหม่ทุกครั้ง (ไม่ใช่ static const) เพราะต้องส่ง callback
  // _navigateToTab เข้าไปให้แผ่น Explore ที่ลากได้ใช้สลับ tab ตอนลากสุดขอบ
  List<Widget> get _pages => [
        HomePage(onNavigateToTab: _navigateToTab),
        InventoryPage(onNavigateToTab: _navigateToTab),
        const ExplorePage(),
        PartyPage(onNavigateToTab: _navigateToTab),
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
