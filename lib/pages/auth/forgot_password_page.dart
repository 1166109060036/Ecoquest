import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/bubble_toast.dart';

// หน้าลืมรหัสผ่าน — 3 ขั้นตอนในหน้าเดียว: กรอกอีเมล -> กรอก OTP ที่ได้รับทางอีเมล -> ตั้งรหัสผ่านใหม่
// หน้าตาเข้าชุดกับ Login/Register (widgets/auth_shell.dart — ปรับใหม่ 14 ต.ค. 2026): พื้นหลังรูป + การ์ดกระจก
// + แถบบอกขั้นตอน 1-2-3 ด้านบนการ์ด
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { email, otp, newPassword }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _Step _step = _Step.email;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.requestPasswordResetOtp(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _step = _Step.otp);
      showBubbleToast(context, 'If this email is registered, we have sent a code to it');
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Failed to send the code');
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      showBubbleToast(context, 'Please enter the 6-digit code');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final resetToken = await authProvider.verifyPasswordResetOtp(
      _emailController.text.trim(),
      _otpController.text.trim(),
    );

    if (!mounted) return;

    if (resetToken != null) {
      _resetToken = resetToken;
      setState(() => _step = _Step.newPassword);
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Invalid or expired code');
    }
  }

  Future<void> _handleResetPassword() async {
    if (_newPasswordController.text.length < 6) {
      showBubbleToast(context, 'Password must be at least 6 characters');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      showBubbleToast(context, 'New passwords do not match');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(_resetToken!, _newPasswordController.text);

    if (!mounted) return;

    if (success) {
      showBubbleToast(context, 'Password reset successfully. Please sign in again');
      Navigator.pop(context);
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Failed to reset password');
    }
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
              title: 'Forgot password',
              subtitle: 'We will help you get back to your quests',
              icon: Icons.lock_reset_rounded,
              logoSize: 64,
            ),
          ),
          const SizedBox(height: 22),
          _StepIndicator(current: _step.index),
          const SizedBox(height: 14),
          AuthEntrance(
            order: 1,
            child: AuthGlassCard(
              // เฟดสลับเนื้อหาแต่ละขั้น แทนตัดฉับ
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.email => _EmailStep(
                      formKey: _formKey,
                      controller: _emailController,
                      isLoading: isLoading,
                      onSubmit: _handleRequestOtp,
                    ),
                    _Step.otp => _OtpStep(
                      email: _emailController.text.trim(),
                      controller: _otpController,
                      isLoading: isLoading,
                      onSubmit: _handleVerifyOtp,
                      onBack: () => setState(() => _step = _Step.email),
                    ),
                    _Step.newPassword => _NewPasswordStep(
                      newPasswordController: _newPasswordController,
                      confirmPasswordController: _confirmPasswordController,
                      isLoading: isLoading,
                      onSubmit: _handleResetPassword,
                    ),
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AuthEntrance(
            order: 2,
            child: AuthSwitchLink(
              text: 'Remember your password?',
              action: 'Sign in',
              onTap: () => Navigator.maybePop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// แถบ 1 Email — 2 Code — 3 New password (ขั้นที่ผ่านแล้วเป็นติ๊กเขียว)
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['Email', 'Code', 'New password'];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      final done = i < current;
      final active = i == current;
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? const Color(0xFF43A047) : Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: active ? Colors.greenAccent : Colors.white.withValues(alpha: 0.3),
                  width: active ? 2 : 1,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[i],
              style: TextStyle(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.65),
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
        ),
      );
      if (i < _labels.length - 1) {
        children.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
              color: i < current ? const Color(0xFF43A047) : Colors.white.withValues(alpha: 0.25),
            ),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
    );
  }
}

TextStyle get _hintStyle => TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5, height: 1.4);

class _EmailStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _EmailStep({required this.formKey, required this.controller, required this.isLoading, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter the email you signed up with and we will send you a 6-digit code.', style: _hintStyle),
          const SizedBox(height: 18),
          AuthTextField(
            controller: controller,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.validateEmail,
            onSubmitted: (_) => isLoading ? null : onSubmit(),
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(label: 'Send code', loading: isLoading, onPressed: onSubmit),
        ],
      ),
    );
  }
}

class _OtpStep extends StatelessWidget {
  final String email;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _OtpStep({
    required this.email,
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Enter the 6-digit code we sent to\n'),
              TextSpan(
                text: email,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: _hintStyle,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => isLoading ? null : onSubmit(),
          cursorColor: Colors.greenAccent,
          style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            hintText: '······',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), letterSpacing: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.10),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: Colors.greenAccent, width: 1.5)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Didn't get it? Check your spam folder.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(label: 'Verify code', loading: isLoading, onPressed: onSubmit),
        const SizedBox(height: 4),
        TextButton(
          onPressed: isLoading ? null : onBack,
          style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.85)),
          child: const Text('Change email / resend code'),
        ),
      ],
    );
  }
}

class _NewPasswordStep extends StatelessWidget {
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _NewPasswordStep({
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a new password with at least 6 characters.', style: _hintStyle),
        const SizedBox(height: 18),
        AuthTextField(
          controller: newPasswordController,
          label: 'New password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: confirmPasswordController,
          label: 'Confirm new password',
          icon: Icons.lock_reset_rounded,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isLoading ? null : onSubmit(),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(label: 'Reset password', loading: isLoading, onPressed: onSubmit),
      ],
    );
  }
}
