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

  // ลำดับต้องตรงกับลำดับปุ่มใน AppBottomNavBar (Home, Inventory, Explore, Party, Profile)
  static const _pages = [
    HomePage(),
    InventoryPage(),
    ExplorePage(),
    PartyPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
