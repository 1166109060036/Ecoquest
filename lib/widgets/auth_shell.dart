import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import 'falling_leaves_overlay.dart';
import 'pressable_scale.dart';
import 'staggered_fade_in.dart';

// ชิ้นส่วนหน้าตาที่หน้า Login / Register ใช้ร่วมกัน (ปรับให้สวยขึ้น 14 ต.ค. 2026)
// ภาพพื้นหลังเดียวกับหน้า Profile/Settings + ใบไม้ร่วง + การ์ดกระจกฝ้า ให้รู้สึกเป็นแอพเดียวกันตั้งแต่หน้าแรก

// พื้นหลังเต็มจอ + ไล่สีเข้มด้านล่างให้ตัวหนังสือสีขาวอ่านง่าย + เนื้อหาเลื่อนได้ (คีย์บอร์ดเด้งไม่ล้น)
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const AuthScaffold({super.key, required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppConstants.profileBgAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3E5C4E), Color(0xFF2C3E50)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.70),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: FallingLeavesOverlay())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  // เนื้อหาสั้นกว่าจอ = อยู่กึ่งกลาง / ยาวกว่า (คีย์บอร์ดขึ้น) = เลื่อนได้
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child),
                  ),
                ),
              ),
            ),
          ),
          if (showBack)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.38),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// โลโก้ในวงกลมเรืองแสงเขียว + ชื่อแอพ + คำโปรย
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double logoSize;
  // ใส่ไอคอนแทนโลโก้ (เช่นหน้า Forgot password)
  final IconData? icon;

  const AuthHeader({super.key, required this.title, required this.subtitle, this.logoSize = 92, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Floating(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              boxShadow: [
                BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 2),
              ],
            ),
            child: icon != null
                ? SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Icon(icon, size: logoSize * 0.6, color: const Color(0xFF2E7D32)),
                  )
                : Image.asset('lib/utils/assets/logo.png', width: logoSize, height: logoSize),
          ),
        ),
        // หน้า Splash ใช้แค่โลโก้ (ส่ง title ว่าง) แล้ววาดชื่อแอพเองพร้อมแอนิเมชัน
        if (title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ],
      ],
    );
  }
}

// โลโก้ลอยขึ้นลงช้าๆ ตลอด (เหมือนไอเทมในเกม) — โหมดลดการเคลื่อนไหวไม่ลอย
class _Floating extends StatefulWidget {
  final Widget child;
  const _Floating({required this.child});

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(offset: Offset(0, -6 * t), child: child);
      },
      child: widget.child,
    );
  }
}

// ไล่ชิ้นส่วนหน้า Login/Register/Forgot ให้โผล่ทีละชิ้น (หัว -> การ์ด -> ลิงก์ล่าง) ตอนเปิดหน้า
class AuthEntrance extends StatelessWidget {
  final int order;
  final Widget child;
  const AuthEntrance({super.key, required this.order, required this.child});

  @override
  Widget build(BuildContext context) => FadeSlideIn(
    delay: Duration(milliseconds: 120 * order),
    duration: const Duration(milliseconds: 520),
    offsetY: 28,
    child: child,
  );
}

// การ์ดกระจกฝ้า (เบลอพื้นหลัง) ครอบฟอร์ม
class AuthGlassCard extends StatelessWidget {
  final Widget child;
  const AuthGlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ช่องกรอกโทนเข้ม ไอคอนหน้า + ปุ่มดู/ซ่อนรหัสผ่าน
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final int? maxLength; // ตัดที่ความยาวนี้ ไม่โชว์ตัวนับ

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.autofillHints,
    this.maxLength,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      inputFormatters: [if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength)],
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: Colors.greenAccent,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        floatingLabelStyle: const TextStyle(color: Colors.greenAccent),
        prefixIcon: Icon(widget.icon, color: Colors.white70, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: const TextStyle(color: Color(0xFFFFB4A9)),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.18)),
        focusedBorder: _border(Colors.greenAccent, 1.5),
        errorBorder: _border(const Color(0xFFFFB4A9)),
        focusedErrorBorder: _border(const Color(0xFFFFB4A9), 1.5),
      ),
    );
  }
}

// ปุ่มหลักสีเขียวไล่เฉด ทรงแคปซูล + วงหมุนตอนโหลด
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return PressableScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: enabled
                ? const [Color(0xFF43A047), Color(0xFF2E7D32)]
                : [Colors.grey.shade600, Colors.grey.shade700],
          ),
          boxShadow: enabled
              ? [BoxShadow(color: Colors.green.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 52,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ปุ่มรองแบบขอบขาวโปร่ง
class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const AuthSecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.person_outline, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
    );
  }
}

// เส้นคั่น "or"
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25), thickness: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
        ),
        line,
      ],
    );
  }
}

// บรรทัดล่าง "Don't have an account? Sign up"
class AuthSwitchLink extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({super.key, required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Wrap แทน Row — จอแคบ/ตัวหนังสือใหญ่ (ตั้งค่าเครื่อง) ปุ่มตกบรรทัดใหม่แทนล้นจอ
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.greenAccent,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}

// ช่องกรอก OTP 6 หลัก + ปุ่มยืนยัน — ใช้ร่วมกันระหว่างหน้าลืมรหัสผ่านกับหน้ายืนยันอีเมลตอนสมัคร
class AuthOtpStep extends StatelessWidget {
  final String email;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final String backLabel;

  const AuthOtpStep({
    super.key,
    required this.email,
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
    this.backLabel = 'Change email / resend code',
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
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5, height: 1.4),
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
          child: Text(backLabel),
        ),
      ],
    );
  }
}
