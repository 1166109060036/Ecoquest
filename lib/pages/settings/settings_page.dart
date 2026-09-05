import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

// หน้า Settings — เข้าถึงจากปุ่ม Settings บนหน้า Profile
// ตอนนี้มีแค่ข้อมูลบัญชี + ปุ่ม Logout (ใช้งานได้จริง) ยังไม่มี toggle/setting อื่น
// เพราะยังไม่มี backend/state รองรับ ใส่ไปตอนนี้จะกลายเป็น UI หลอกที่กดแล้วไม่ทำอะไร
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ออกจากระบบ?'),
        content: const Text('คุณจะต้องเข้าสู่ระบบใหม่อีกครั้งเพื่อใช้งานต่อ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    // ล้าง stack ทั้งหมดตอน logout ไม่ใช่แค่ replace หน้าเดียว เพราะ Settings อยู่ทับ
    // MainShell ซึ่งเป็น session ที่ล็อกอินอยู่ ถ้าแค่ replace จะเหลือ MainShell ค้างอยู่
    // ใต้หน้า Login ในสแตก กด back กลับเข้าแอปที่ล็อกอินอยู่ได้ทั้งที่ logout ไปแล้ว
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _SettingsBackground()),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TopBar(),
                    const SizedBox(height: 20),
                    _AccountCard(
                      displayName: user?.displayName ?? 'Player',
                      email: user?.email,
                      isGuest: user?.isGuest ?? false,
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => _confirmLogout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

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
// แถบบนสุด: ปุ่มย้อนกลับ + หัวข้อ "SETTINGS"
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
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
              Icon(Icons.settings, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'SETTINGS',
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
        // เว้นที่ว่างเท่าปุ่มย้อนกลับฝั่งซ้าย เพื่อให้หัวข้อ "SETTINGS" อยู่กึ่งกลางจอจริงๆ
        const SizedBox(width: 36),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดข้อมูลบัญชี — ชื่อ + อีเมล (ถ้ามี) อ่านจาก AuthProvider ตรงๆ ไม่ใช่ mock
// ---------------------------------------------------------------------------
class _AccountCard extends StatelessWidget {
  final String displayName;
  final String? email;
  final bool isGuest;

  const _AccountCard({required this.displayName, this.email, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.black.withOpacity(0.4),
            child: const Icon(Icons.person, color: Colors.white70, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isGuest ? 'Guest Account' : (email ?? ''),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
