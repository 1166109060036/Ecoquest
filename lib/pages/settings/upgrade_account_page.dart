import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

// หน้าเปลี่ยนบัญชี Guest -> บัญชีปกติ (ตั้งชื่อ + email + password)
// เข้าจากเมนูในหน้า Settings ซึ่งจะโชว์เฉพาะตอนที่ล็อกอินอยู่แบบ Guest
//
// backend ใช้ user เดิม (_id ไม่เปลี่ยน) เลยไม่ต้อง login ใหม่ และความคืบหน้าทั้งหมดติดมาครบ
class UpgradeAccountPage extends StatefulWidget {
  const UpgradeAccountPage({super.key});

  @override
  State<UpgradeAccountPage> createState() => _UpgradeAccountPageState();
}

class _UpgradeAccountPageState extends State<UpgradeAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.upgradeGuest(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! You can now sign in with your email.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to create your account')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
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
                    _TopBar(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Your progress stays with you — points, quests and fridge items all carry over.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                _DarkField(
                                  controller: _nameController,
                                  label: 'Display name',
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a display name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _DarkField(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: Validators.validateEmail,
                                ),
                                const SizedBox(height: 16),
                                _DarkField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  obscure: true,
                                  validator: Validators.validatePassword,
                                ),
                                const SizedBox(height: 16),
                                _DarkField(
                                  controller: _confirmController,
                                  label: 'Confirm password',
                                  obscure: true,
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: isLoading ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28)),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Create Account',
                                          style: TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _Background extends StatelessWidget {
  const _Background();

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
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const Expanded(
          child: Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 36),
      ],
    );
  }
}

// ช่องกรอกธีมมืดให้เข้ากับพื้นหลังรูป (ธีมสว่างปกติจะอ่านไม่ออกบนพื้นนี้)
class _DarkField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?) validator;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.validator,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  State<_DarkField> createState() => _DarkFieldState();
}

class _DarkFieldState extends State<_DarkField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  _hidden ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.green),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
