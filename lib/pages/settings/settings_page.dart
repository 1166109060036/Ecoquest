import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/sound_service.dart';
import '../../utils/constants.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/falling_leaves_overlay.dart';
import '../../widgets/liquid_glass_dialog.dart';

// หน้า Settings — เข้าถึงจากปุ่ม Settings บนหน้า Profile
// ตอนนี้มีแค่ข้อมูลบัญชี + ปุ่ม Logout (ใช้งานได้จริง) ยังไม่มี toggle/setting อื่น
// เพราะยังไม่มี backend/state รองรับ ใส่ไปตอนนี้จะกลายเป็น UI หลอกที่กดแล้วไม่ทำอะไร
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _editDisplayName(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final controller = TextEditingController(text: authProvider.user?.displayName ?? '');

    final newName = await LiquidGlassDialog.show<String>(
      context: context,
      title: 'Edit Display Name',
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 20,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Your name',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        ),
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        LiquidGlassAction(
          label: 'Save',
          color: Colors.green,
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );

    if (newName == null || newName.isEmpty || !context.mounted) return;

    final success = await authProvider.updateDisplayName(newName);
    if (!context.mounted) return;

    showBubbleToast(
      context,
      success ? 'Display name updated' : (authProvider.errorMessage ?? 'Failed to update your name'),
    );
  }

  void _showAbout(BuildContext context) {
    LiquidGlassDialog.show<void>(
      context: context,
      icon: const Icon(Icons.eco_rounded, color: Colors.green, size: 30),
      title: 'About EcoQuest',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Version ${AppConstants.appVersion}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
              )),
          const SizedBox(height: 10),
          const Text(
            'An environmental gamification app that turns everyday eco-friendly actions '
            'in Ebetsu City into quests, points, and rewards.',
            textAlign: TextAlign.center,
            style: LiquidGlassDialog.messageStyle,
          ),
        ],
      ),
      actions: [
        LiquidGlassAction(label: 'Close', color: Colors.green, onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 28),
      title: 'Log out?',
      content: const Text(
        'You will need to sign in again to continue',
        textAlign: TextAlign.center,
        style: LiquidGlassDialog.messageStyle,
      ),
      actions: [
        LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(
          label: 'Log Out',
          color: Colors.redAccent,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed != true || !context.mounted) return;

    // ตัด WebSocket ของแชทก่อน logout เสมอ — กัน session ใหม่ (login คนละบัญชี) แอบได้รับ
    // event แชทของบัญชีเก่าที่ยังต่อค้างอยู่
    context.read<ChatProvider>().disconnect();
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
                    _VolumeSliderItem(
                      icon: Icons.music_note_outlined,
                      label: 'Background Music',
                      initialValue: SoundService.instance.musicVolume,
                      onChanged: (v) => SoundService.instance.setMusicVolume(v, persist: false),
                      onChangeEnd: (v) => SoundService.instance.setMusicVolume(v),
                    ),
                    const SizedBox(height: 14),
                    _VolumeSliderItem(
                      icon: Icons.volume_up_outlined,
                      label: 'Sound Effects',
                      initialValue: SoundService.instance.clickVolume,
                      onChanged: (v) => SoundService.instance.setClickVolume(v, persist: false),
                      onChangeEnd: (v) => SoundService.instance.setClickVolume(v),
                    ),
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
      showBubbleToast(context, authProvider.errorMessage ?? 'Failed to update notification setting');
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
// การ์ดสไลเดอร์ปรับระดับเสียง — ใช้กับทั้งเพลงพื้นหลังและเสียงระบบ (ปุ่มกด) แยกกันคนละใบ
// เก็บ state ไว้เองแบบ optimistic เหมือน _NotificationToggleItem: ลากแล้วเห็น/ได้ยินผลทันที
// (onChanged เรียก SoundService แบบ persist: false ปรับเสียงสดๆ ไม่เขียนดิสก์ทุกเฟรมที่ลาก)
// ค่อยเขียนดิสก์จริงตอนปล่อยนิ้ว (onChangeEnd)
// ---------------------------------------------------------------------------
class _VolumeSliderItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final double initialValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _VolumeSliderItem({
    required this.icon,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_VolumeSliderItem> createState() => _VolumeSliderItemState();
}

class _VolumeSliderItemState extends State<_VolumeSliderItem> {
  late double _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_value == 0 ? Icons.volume_off : widget.icon, color: Colors.white70, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${(_value * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.green,
              thumbColor: Colors.green,
              inactiveTrackColor: Colors.white.withOpacity(0.15),
              overlayColor: Colors.green.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: _value,
              onChanged: (v) {
                setState(() => _value = v);
                widget.onChanged(v);
              },
              onChangeEnd: widget.onChangeEnd,
            ),
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
