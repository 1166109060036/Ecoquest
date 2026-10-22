import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/bubble_toast.dart';

// Admin 2FA (22 ต.ค. 2026) — ต้องกรอก OTP ทางอีเมลก่อนเข้า Admin Tools ทุกครั้งที่เปิดแอพใหม่
// (backend เช็คจริงที่ middleware/admin.js — หน้านี้แค่ขอ/ยืนยันรหัส) เปิดหน้ามาส่งรหัสให้ทันที
// ยืนยันผ่าน = token เก็บใน api_http.adminToken แล้วเปลี่ยนไปหน้า /admin
class AdminVerifyPage extends StatefulWidget {
  const AdminVerifyPage({super.key});

  @override
  State<AdminVerifyPage> createState() => _AdminVerifyPageState();
}

class _AdminVerifyPageState extends State<AdminVerifyPage> {
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleSend();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendAdminOtp();

    if (!mounted) return;
    showBubbleToast(
      context,
      success ? 'We have sent an admin code to your email' : authProvider.errorMessage ?? 'Failed to send the code',
    );
  }

  Future<void> _handleVerify() async {
    if (_otpController.text.trim().length != 6) {
      showBubbleToast(context, 'Please enter the 6-digit code');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyAdminOtp(_otpController.text.trim());

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Invalid or expired code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          AuthEntrance(
            order: 0,
            child: const AuthHeader(
              title: 'Admin verification',
              subtitle: 'Confirm it is you before using admin tools',
              icon: Icons.admin_panel_settings_outlined,
              logoSize: 64,
            ),
          ),
          const SizedBox(height: 22),
          AuthEntrance(
            order: 1,
            child: AuthGlassCard(
              child: AuthOtpStep(
                email: auth.user?.email ?? '',
                controller: _otpController,
                isLoading: auth.isLoading,
                onSubmit: _handleVerify,
                onBack: _handleSend,
                backLabel: 'Resend code',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
