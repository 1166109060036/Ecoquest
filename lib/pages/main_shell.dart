import 'package:flutter/material.dart';
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

  void _navigateToTab(int index) => setState(() => _currentIndex = index);

  // ลำดับต้องตรงกับลำดับปุ่มใน AppBottomNavBar (Home, Inventory, Explore, Party, Profile)
  // HomePage ต้อง build ใหม่ทุกครั้ง (ไม่ใช่ static const) เพราะต้องส่ง callback
  // _navigateToTab เข้าไปให้แผ่น Explore ที่ลากได้ใช้สลับ tab ตอนลากสุดขอบ
  List<Widget> get _pages => [
        HomePage(onNavigateToTab: _navigateToTab),
        const InventoryPage(),
        const ExplorePage(),
        const PartyPage(),
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
