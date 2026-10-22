import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/bubble_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/main');
    } else if (authProvider.unverifiedEmail != null) {
      Navigator.pushNamed(context, '/verify-email',
          arguments: {'email': authProvider.unverifiedEmail, 'resend': true});
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Something went wrong');
    }
  }

  Future<void> _handleGuestLogin() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginAsGuest();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Something went wrong');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final loading = authProvider.isLoading;

    // หน้าตาใหม่ (14 ต.ค. 2026): พื้นหลังเดียวกับหน้า Profile + การ์ดกระจก — ชิ้นส่วนอยู่ใน widgets/auth_shell.dart
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthEntrance(
            order: 0,
            child: const AuthHeader(title: 'EcoQuest', subtitle: 'Small eco quests, real impact'),
          ),
          const SizedBox(height: 28),
          AuthEntrance(
            order: 1,
            child: AuthGlassCard(
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue your quests',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.validateEmail,
                      ),
                      const SizedBox(height: 14),
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: Validators.validatePassword,
                        onSubmitted: (_) => loading ? null : _handleLogin(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.85)),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AuthPrimaryButton(label: 'Sign In', loading: loading, onPressed: _handleLogin),
                      const SizedBox(height: 16),
                      const AuthOrDivider(),
                      const SizedBox(height: 16),
                      AuthSecondaryButton(
                        label: 'Continue as Guest',
                        icon: Icons.explore_outlined,
                        onPressed: loading ? null : _handleGuestLogin,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AuthEntrance(
            order: 2,
            child: AuthSwitchLink(
              text: "Don't have an account?",
              action: 'Sign up',
              onTap: () => Navigator.pushNamed(context, '/register'),
            ),
          ),
        ],
      ),
    );
  }
}
