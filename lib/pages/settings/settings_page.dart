import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/falling_leaves_overlay.dart';

// หน้า Settings — เข้าถึงจากปุ่ม Settings บนหน้า Profile
// ตอนนี้มีแค่ข้อมูลบัญชี + ปุ่ม Logout (ใช้งานได้จริง) ยังไม่มี toggle/setting อื่น
// เพราะยังไม่มี backend/state รองรับ ใส่ไปตอนนี้จะกลายเป็น UI หลอกที่กดแล้วไม่ทำอะไร
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _editDisplayName(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final controller = TextEditingController(text: authProvider.user?.displayName ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !context.mounted) return;

    final success = await authProvider.updateDisplayName(newName);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Display name updated' : (authProvider.errorMessage ?? 'Failed to update your name')),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About EcoQuest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${AppConstants.appVersion}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            const Text(
              'An environmental gamification app that turns everyday eco-friendly actions '
              'in Ebetsu City into quests, points, and rewards.',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();
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
                    Colors.black.withOpacity(0.53),
                    Colors.black.withOpacity(0.33),
                    Colors.black.withOpacity(0.63),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: FallingLeavesOverlay()),
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
                    const SizedBox(height: 14),
                    _SettingsMenuItem(
                      icon: Icons.badge_outlined,
                      label: 'Edit Display Name',
                      onTap: () => _editDisplayName(context),
                    ),
                    if (user?.isGuest ?? false) ...[
                      // Guest ล็อกอินกลับเข้าบัญชีเดิมไม่ได้เลยถ้า logout (ไม่มี email/password)
                      // เมนูนี้เลยเน้นให้เห็นชัดกว่าเมนูอื่น
                      const SizedBox(height: 14),
                      _SettingsMenuItem(
                        icon: Icons.person_add_alt,
                        label: 'Create an account',
                        subtitle: 'Guest progress is lost when you log out',
                        highlighted: true,
                        onTap: () => Navigator.pushNamed(context, '/upgrade-account'),
                      ),
                    ] else ...[
                      // บัญชี Guest ไม่มีรหัสผ่าน เลยไม่ต้องมีเมนูนี้ให้กด
                      const SizedBox(height: 14),
                      _SettingsMenuItem(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        onTap: () => Navigator.pushNamed(context, '/change-password'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _NotificationToggleItem(initialValue: user?.notificationsEnabled ?? true),
                    const SizedBox(height: 14),
                    _SettingsMenuItem(
                      icon: Icons.info_outline,
                      label: 'About',
                      onTap: () => _showAbout(context),
                    ),
                    if (user?.isAdmin ?? false) ...[
                      // dev/QA เท่านั้น — เห็นเฉพาะบัญชีที่อีเมลอยู่ใน ADMIN_EMAILS ฝั่ง backend
                      const SizedBox(height: 14),
                      _SettingsMenuItem(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin Tools',
                        onTap: () => Navigator.pushNamed(context, '/admin'),
                      ),
                    ],
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
              color: Colors.black.withOpacity(0.38),
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
        color: Colors.black.withOpacity(0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.black.withOpacity(0.48),
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

// ---------------------------------------------------------------------------
// การ์ด toggle เปิด/ปิดการแจ้งเตือน — เก็บ state ไว้เองแบบ optimistic (สลับ UI ทันทีตอนกด
// ไม่ต้องรอ backend ตอบ) ถ้า backend ตอบว่าพังค่อยสลับกลับ + โชว์ snackbar อธิบาย
// ---------------------------------------------------------------------------
class _NotificationToggleItem extends StatefulWidget {
  final bool initialValue;
  const _NotificationToggleItem({required this.initialValue});

  @override
  State<_NotificationToggleItem> createState() => _NotificationToggleItemState();
}

class _NotificationToggleItemState extends State<_NotificationToggleItem> {
  late bool _enabled = widget.initialValue;

  Future<void> _handleChanged(bool value) async {
    setState(() => _enabled = value);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateNotificationPreference(value);
    if (!mounted) return;

    if (!success) {
      setState(() => _enabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to update notification setting')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined, color: Colors.white70, size: 20),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: _enabled,
            activeThumbColor: Colors.green,
            onChanged: _handleChanged,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// เมนูรายการเดียวสไตล์กระจก (icon + label + ลูกศร) — ใช้กับ "Change Password" และเมนูอื่นในอนาคต
// ---------------------------------------------------------------------------
class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool highlighted; // เมนูที่อยากให้เด่นกว่าเมนูอื่น (ขอบ+ไอคอนสีเขียว)
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.46),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? Colors.green.withOpacity(0.55)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: highlighted ? Colors.greenAccent : Colors.white70, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
