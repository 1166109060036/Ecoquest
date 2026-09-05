import 'package:flutter/material.dart';
import '../../models/party_model.dart';
import '../../utils/constants.dart';

// หน้า Party — โชว์ปาร์ตี้ปัจจุบันของผู้เล่น (leader + สมาชิก ต่อด้วยปุ่ม Leave Party)
// ถ้ายังไม่มีปาร์ตี้ โชว์ empty state พร้อมปุ่มพาไปหน้า Explore เพื่อไปหา Party Quest มาเข้าร่วม
// TODO: ต่อกับ Party API จริงตอนมี backend endpoint (get/leave ปาร์ตี้ปัจจุบัน)
class PartyPage extends StatefulWidget {
  // MainShell ส่ง callback นี้เข้ามาเพื่อสลับ tab ของ bottom nav (ปุ่มย้อนกลับ / ปุ่ม Explore Quest)
  final ValueChanged<int>? onNavigateToTab;

  const PartyPage({super.key, this.onNavigateToTab});

  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  // ลำดับ index ต้องตรงกับ AppBottomNavBar (Home=0, Inventory=1, Explore=2, Party=3, Profile=4)
  static const int _homeTabIndex = 0;
  static const int _exploreTabIndex = 2;

  // mock ไว้ก่อน — TODO: ดึงปาร์ตี้ปัจจุบันจาก backend จริงตอนมี endpoint
  PartyModel? _party = mockParty;

  Future<void> _confirmLeaveParty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ออกจากปาร์ตี้?'),
        content: const Text('คุณจะออกจากปาร์ตี้นี้ และต้องเข้าร่วมใหม่ทีหลังถ้าเปลี่ยนใจ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากปาร์ตี้', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // TODO: เรียก API ออกจากปาร์ตี้จริงตอนมี endpoint
      setState(() => _party = null);
    }
  }

  void _viewMemberProfile(String name) {
    // TODO: เปิดหน้าโปรไฟล์ของผู้เล่นคนอื่นจริงตอนมี endpoint
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ดูโปรไฟล์ $name — เร็วๆ นี้')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ---- พื้นหลัง: ใช้รูปเดียวกับหน้า Profile ให้ธีมไปด้วยกัน ----
          const Positioned.fill(child: _PartyBackground()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.25),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    _TopBar(onBack: () => widget.onNavigateToTab?.call(_homeTabIndex)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _party == null
                          ? _NoPartyState(
                              onExplore: () => widget.onNavigateToTab?.call(_exploreTabIndex),
                            )
                          : _PartyRoster(
                              party: _party!,
                              onTapMember: _viewMemberProfile,
                              onLeave: _confirmLeaveParty,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// พื้นหลัง — ใช้รูปเดียวกับ AppConstants.profileBgAsset (ไม่มีรูปก็ fallback เป็น gradient)
// ---------------------------------------------------------------------------
class _PartyBackground extends StatelessWidget {
  const _PartyBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.profileBgAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3E5C4E), Color(0xFF2C3E50)],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// แถบบนสุด: ปุ่มย้อนกลับ (ไป Home) + หัวข้อ "PARTY"
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.groups_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'PARTY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // เว้นที่ว่างเท่าปุ่มย้อนกลับฝั่งซ้าย เพื่อให้หัวข้อ "PARTY" อยู่กึ่งกลางจอจริงๆ
        const SizedBox(width: 36),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดรายชื่อปาร์ตี้: leader อยู่บนสุด (กดดูโปรไฟล์ได้) ตามด้วยสมาชิก + ปุ่ม Leave Party
// ---------------------------------------------------------------------------
class _PartyRoster extends StatelessWidget {
  final PartyModel party;
  final ValueChanged<String> onTapMember;
  final VoidCallback onLeave;

  const _PartyRoster({
    required this.party,
    required this.onTapMember,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _MemberRow(
                    name: party.leader.name,
                    roleLabel: 'Party Leader',
                    showArrow: true,
                    onTap: () => onTapMember(party.leader.name),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: Colors.white.withOpacity(0.15), height: 1),
                  ),
                  for (final member in party.members)
                    _MemberRow(
                      name: member.name,
                      roleLabel: 'Party Member',
                      onTap: () => onTapMember(member.name),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onLeave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Leave Party', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name;
  final String roleLabel;
  final bool showArrow;
  final VoidCallback onTap;

  const _MemberRow({
    required this.name,
    required this.roleLabel,
    this.showArrow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.black.withOpacity(0.4),
              child: const Icon(Icons.person, color: Colors.white70, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(roleLabel, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            if (showArrow) const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — ยังไม่มีปาร์ตี้ พาไปหน้า Explore เพื่อหา Party Quest มาเข้าร่วม
// ---------------------------------------------------------------------------
class _NoPartyState extends StatelessWidget {
  final VoidCallback onExplore;
  const _NoPartyState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 56, color: Colors.white.withOpacity(0.7)),
          const SizedBox(height: 16),
          const Text(
            'คุณยังไม่มีปาร์ตี้',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'เข้าร่วม Party Quest เพื่อรวมทีมกับผู้เล่นคนอื่น',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onExplore,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Explore Quest', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
