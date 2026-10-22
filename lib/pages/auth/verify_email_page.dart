import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/bubble_toast.dart';

// หน้ายืนยันอีเมลด้วย OTP หลังสมัคร (22 ต.ค. 2026) — ยืนยันผ่านแล้วถึงได้ token เข้าแอพ
// arguments: {'email': String, 'resend': bool} — resend = true ตอนมาจากหน้า Login (บัญชีสมัครค้างไว้ OTP เดิม
// อาจหมดอายุแล้ว) ขอ OTP ใหม่ให้ทันทีที่เปิดหน้า / มาจากหน้า Register ไม่ต้องขอ (backend ส่งไปแล้วตอนสมัคร)
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _otpController = TextEditingController();

  Map<String, dynamic> get _args => ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  String get _email => _args['email'] as String;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _args['resend'] == true) _handleResend();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (_otpController.text.trim().length != 6) {
      showBubbleToast(context, 'Please enter the 6-digit code');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyEmail(_email, _otpController.text.trim());

    if (!mounted) return;

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Invalid or expired code');
    }
  }

  Future<void> _handleResend() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationOtp(_email);

    if (!mounted) return;
    showBubbleToast(
      context,
      success ? 'We have sent a new code to your email' : authProvider.errorMessage ?? 'Failed to send the code',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return AuthScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          AuthEntrance(
            order: 0,
            child: const AuthHeader(
              title: 'Verify your email',
              subtitle: 'One last step before your first quest',
              icon: Icons.mark_email_read_outlined,
              logoSize: 64,
            ),
          ),
          const SizedBox(height: 22),
          AuthEntrance(
            order: 1,
            child: AuthGlassCard(
              child: AuthOtpStep(
                email: _email,
                controller: _otpController,
                isLoading: isLoading,
                onSubmit: _handleVerify,
                onBack: _handleResend,
                backLabel: 'Resend code',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
