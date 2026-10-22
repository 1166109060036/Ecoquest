import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/bubble_toast.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/verify-email',
          arguments: {'email': _emailController.text.trim(), 'resend': false});
    } else {
      showBubbleToast(context, authProvider.errorMessage ?? 'Something went wrong');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final loading = authProvider.isLoading;

    // หน้าตาเดียวกับหน้า Login (widgets/auth_shell.dart)
    return AuthScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          AuthEntrance(
            order: 0,
            child: const AuthHeader(
              title: 'Join EcoQuest',
              subtitle: 'Create an account to keep your progress',
              logoSize: 64,
            ),
          ),
          const SizedBox(height: 22),
          AuthEntrance(
            order: 1,
            child: AuthGlassCard(
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        controller: _displayNameController,
                        label: 'Display name (optional)',
                        icon: Icons.badge_outlined,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.nickname],
                      ),
                      const SizedBox(height: 14),
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
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: Validators.validatePassword,
                      ),
                      const SizedBox(height: 14),
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm password',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                        onSubmitted: (_) => loading ? null : _handleRegister(),
                      ),
                      const SizedBox(height: 22),
                      AuthPrimaryButton(label: 'Create account', loading: loading, onPressed: _handleRegister),
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
              text: 'Already have an account?',
              action: 'Sign in',
              onTap: () => Navigator.maybePop(context),
            ),
          ),
        ],
      ),
    );
  }
}
