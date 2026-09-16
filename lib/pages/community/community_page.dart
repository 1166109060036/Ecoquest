import 'package:flutter/material.dart';
import 'chat_tab.dart';
import 'friend_tab.dart';
import 'party_tab.dart';

// หน้า Community — แทนที่หน้า Party เดิมในแท็บล่างสุด (index 3 เหมือนเดิม แค่เปลี่ยนชื่อ/ไอคอน
// ดู bottom_nav_bar.dart) มี 3 แท็บย่อยผ่าน TabBar (⚠️ เป็น TabBar ตัวแรกในโปรเจคนี้ ไม่เคยมีมาก่อน):
//   1) Friend — เพิ่ม/ค้นหาเพื่อน
//   2) Party — ของเดิมจาก party_page.dart ย้ายมาอยู่ตรงนี้ (ดู party_tab.dart)
//   3) Chat — แชทโลก/ปาร์ตี้/เพื่อน
//
// ธีมพื้นหลังสีอ่อน (grey.shade50) ตามหน้า Explore/Inventory ตามที่ขอ — เดิมเคยใช้ธีมเข้ม (รูป
// Profile + gradient ทับ + ใบไม้ลอยตก) เหมือนหน้า Profile/Settings มาก่อน แต่เปลี่ยนแล้วเพราะการ์ด/
// ตัวหนังสือในแท็บ Party (party_tab.dart) ก็ปรับเป็นธีมสว่างตามไปด้วยพร้อมกัน (ดูคอมเมนต์ในไฟล์นั้น)
class CommunityPage extends StatefulWidget {
  // ส่งต่อจาก MainShell เพื่อสลับ tab ของ bottom nav (เช่น แท็บ Party ใช้พาไป Explore/Profile)
  final ValueChanged<int>? onNavigateToTab;

  const CommunityPage({super.key, this.onNavigateToTab});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Community',
                  style: TextStyle(color: Colors.green, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Friend'),
                Tab(text: 'Party'),
                Tab(text: 'Chat'),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    const FriendTab(),
                    PartyTab(onNavigateToTab: widget.onNavigateToTab),
                    const ChatTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
