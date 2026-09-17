import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'particle_burst.dart';

// เรียกแทน ScaffoldMessenger.of(context).showSnackBar(SnackBar(...)) ทุกจุดในแอพ — โชว์เป็นฟองลอย
// ขึ้นมาเบาๆ (สไตล์ liquid glass เดียวกับ LiquidGlassDialog) ค้างอยู่สักพักแล้ว "แตก" ไปเอง
// (auto-dismiss) หรือกดที่ตัวฟองเพื่อแตกเองก่อนเวลาก็ได้
//
// ดีไซน์: กระจกสีดำล้วนโปร่งใส (ไม่ไล่สี) ตัวหนังสือสีขาวตัดกันชัด ใช้ได้ทับพื้นหลังได้ทุกแบบ
// (ทั้งหน้าสว่างอย่าง Explore/Inventory และหน้าเข้มอย่าง Settings/Profile)
//
// มีทีละฟองเดียวพอ — ถ้าเรียกซ้ำตอนฟองเก่ายังลอยอยู่ ฟองเก่าจะแตกเร็วขึ้นทันทีแล้วฟองใหม่ค่อยลอยขึ้นแทน
// (กันฟองซ้อนกันเยอะๆ บนจอ)
VoidCallback? _activeDismiss;

Future<void> showBubbleToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  // มีฟองเก่าอยู่แล้ว -> สั่งให้แตกทันที (ไม่ต้องรอ animation แตกของมันจบ ฟองใหม่ขึ้นมาแทนได้เลย)
  _activeDismiss?.call();

  final overlayState = Overlay.of(context);
  final completer = Completer<void>();
  late OverlayEntry entry;
  bool removed = false;

  void removeEntry() {
    if (removed) return;
    removed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (context) => _BubbleToast(
      message: message,
      duration: duration,
      registerDismiss: (dismiss) => _activeDismiss = dismiss,
      onDismissed: removeEntry,
    ),
  );

  overlayState.insert(entry);
  return completer.future;
}

class _BubbleToast extends StatefulWidget {
  final String message;
  final Duration duration;
  final ValueChanged<VoidCallback> registerDismiss;
  final VoidCallback onDismissed;

  const _BubbleToast({
    required this.message,
    required this.duration,
    required this.registerDismiss,
    required this.onDismissed,
  });

  @override
  State<_BubbleToast> createState() => _BubbleToastState();
}

class _BubbleToastState extends State<_BubbleToast> with TickerProviderStateMixin {
  // ลอยขึ้น + จางเข้ามาตอนโผล่ครั้งแรก
  late final AnimationController _enterController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _enter = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);

  // ขยายตัว + จางหายเร็วตอน "แตก" (เล่นคู่กับ ParticleBurstOverlay ด้านล่าง)
  late final AnimationController _popController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240));

  Timer? _autoPopTimer;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    widget.registerDismiss(_pop);
    _enterController.forward();
    _autoPopTimer = Timer(widget.duration, _pop);
  }

  void _pop() {
    if (_popping) return;
    setState(() => _popping = true);
    _autoPopTimer?.cancel();
    _popController.forward();
    // รอทั้งฟองยุบ (popController) และอนุภาคแตกกระจาย (ParticleBurstOverlay) เล่นจบก่อนค่อยลบ
    // overlay entry ทิ้ง — 320ms ครอบคลุมทั้งสองอย่าง (240ms/280ms ตามลำดับ) พอดี
    Future.delayed(const Duration(milliseconds: 320), widget.onDismissed);
  }

  @override
  void dispose() {
    _autoPopTimer?.cancel();
    _enterController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Stack(
      children: [
        // กล่องขอบเขตแยกไว้ให้ ParticleBurstOverlay เต็มพอดี (ตัวมันเองขอพื้นที่แบบ Size.infinite
        // ต้องมีกรอบจำกัดชัดเจนให้เกาะ ไม่ปล่อยลอยอิสระในกล่องเดียวกับตัวฟองที่มีขนาดตามเนื้อหา)
        if (_popping)
          Positioned(
            left: 24,
            right: 24,
            bottom: bottomPadding - 40,
            height: 160,
            child: IgnorePointer(
              child: ParticleBurstOverlay(
                particleCount: 12,
                color: Colors.lightBlueAccent,
                duration: const Duration(milliseconds: 280),
              ),
            ),
          ),
        Positioned(
          left: 24,
          right: 24,
          bottom: bottomPadding,
          child: AnimatedBuilder(
            animation: Listenable.merge([_enterController, _popController]),
            builder: (context, child) {
              final enter = _enter.value;
              final popT = _popController.value;
              final scale = (0.85 + 0.15 * enter) * (1 + 0.3 * popT);
              final opacity = (enter * (1 - popT)).clamp(0.0, 1.0);
              final translateY = 20 * (1 - enter);

              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
            child: Center(
              child: GestureDetector(
                onTap: _pop,
                child: _BubbleBody(message: widget.message),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final String message;

  const _BubbleBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              // กระจกสีดำล้วนโปร่งใส ไม่ไล่สี — มองทะลุเห็นพื้นหลังจริงของหน้าจอ (liquid glass)
              color: Colors.black.withValues(alpha: 0.42),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // แสงสะท้อนมุมบนซ้าย จำลองผิวโค้งมันวาวของฟองสบู่ — จุดสำคัญที่ทำให้ดูเป็น "ฟอง" จริงๆ
                Positioned(
                  left: 6,
                  top: -2,
                  child: Container(
                    width: 34,
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
