import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'particle_burst.dart';

// เรียกแทน ScaffoldMessenger.of(context).showSnackBar(SnackBar(...)) ทุกจุดในแอพ — โชว์เป็นฟองสบู่ใสๆ
// เด้งพองขึ้นมาจากด้านล่าง ค่อยๆ ลอยขึ้น (ส่ายซ้ายขวา + ยืดหดนิดๆ เหมือนฟองจริง) แล้ว "แตก" ไปเองตรงตำแหน่ง
// ที่ลอยไปถึง (auto-dismiss) หรือกดที่ตัวฟองเพื่อแตกเองก่อนเวลาก็ได้
//
// ดีไซน์: ฟองใส ตรงกลางมืดลงนิดเดียว (พอให้ตัวหนังสือขาวอ่านออกบนหน้าสว่างอย่าง Explore/Inventory)
// ขอบเป็นรุ้งจางๆ หมุนวนช้าๆ + แสงสะท้อน 2 จุด — จุดที่ทำให้ดูเป็น "ฟองสบู่" จริงๆ
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
  static const _riseDistance = 90.0;
  static const _swayAmplitude = 6.0;
  static const _popDuration = Duration(milliseconds: 200);
  static const _burstDuration = Duration(milliseconds: 420);

  // เด้งพองขึ้นมาตอนโผล่ (easeOutBack ให้เกินนิดแล้วเด้งกลับ เหมือนฟองเพิ่งหลุดจากห่วงเป่า)
  late final AnimationController _enterController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _enter = CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack);

  // ลอยขึ้นต่อเนื่องตลอดอายุฟอง — ความยาวเท่ากับ duration ที่ฟองค้างอยู่ ลอยได้ระยะเท่ากันทุกฟอง
  late final AnimationController _floatController = AnimationController(vsync: this, duration: widget.duration);

  // วนไม่หยุด ใช้ทั้งส่ายซ้ายขวา ยืดหดตัวฟอง และหมุนรุ้งที่ขอบ
  late final AnimationController _wobbleController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  late final AnimationController _popController = AnimationController(vsync: this, duration: _popDuration);

  Timer? _autoPopTimer;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    widget.registerDismiss(_pop);
    _enterController.forward();
    _floatController.forward();
    _autoPopTimer = Timer(widget.duration, _pop);
  }

  void _pop() {
    if (_popping || !mounted) return;
    setState(() => _popping = true);
    _autoPopTimer?.cancel();
    // หยุดลอยไว้ตรงนั้นเลย ให้ละอองแตกออกจากตำแหน่งที่ฟองอยู่จริงตอนแตก
    _floatController.stop();
    _popController.forward();
    Future.delayed(_burstDuration, widget.onDismissed);
  }

  @override
  void dispose() {
    _autoPopTimer?.cancel();
    _enterController.dispose();
    _floatController.dispose();
    _wobbleController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomPadding,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enterController, _floatController, _wobbleController, _popController]),
        builder: (context, _) {
          final enter = _enter.value;
          final popT = _popController.value;
          final wave = sin(_wobbleController.value * 2 * pi);

          final rise = _riseDistance * Curves.easeOutSine.transform(_floatController.value);
          final sway = _swayAmplitude * sin(_floatController.value * 2.4 * pi);
          // ยืดแนวนอน-หดแนวตั้งสลับกัน (ปริมาตรคงที่) = ดูเป็นผิวฟองที่บางและนิ่ม
          final jiggle = 0.018 * wave * (1 - popT);
          final grow = (0.55 + 0.45 * enter) * (1 + 0.18 * popT);
          final opacity = (_enterController.value * (1 - popT)).clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(sway, -rise),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: opacity,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(grow * (1 + jiggle), grow * (1 - jiggle), 1),
                      child: GestureDetector(
                        onTap: _pop,
                        child: _BubbleBody(
                          message: widget.message,
                          shimmer: _wobbleController.value,
                        ),
                      ),
                    ),
                  ),
                  if (_popping)
                    Positioned(
                      left: -40,
                      right: -40,
                      top: -70,
                      bottom: -70,
                      child: IgnorePointer(
                        child: ParticleBurstOverlay(
                          particleCount: 16,
                          color: const Color(0xFFD8F4FF),
                          duration: _burstDuration,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  static const _radius = 32.0;

  final String message;
  final double shimmer;

  const _BubbleBody({required this.message, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: CustomPaint(
            foregroundPainter: _BubbleSheenPainter(shimmer: shimmer, radius: _radius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                // ตรงกลางมืดนิดเดียวให้ตัวหนังสืออ่านออก ขอบใสเกือบหมด = ผิวฟองบางๆ ที่มองทะลุได้
                gradient: RadialGradient(
                  radius: 1.4,
                  colors: [
                    Colors.black.withValues(alpha: 0.26),
                    Colors.black.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// วาดทับหน้าตัวฟอง: ขอบรุ้ง (หมุนวนตาม shimmer) + แสงสะท้อนโค้งมุมบนซ้าย + จุดประกายเล็กมุมล่างขวา
class _BubbleSheenPainter extends CustomPainter {
  final double shimmer;
  final double radius;

  _BubbleSheenPainter({required this.shimmer, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(0.9), Radius.circular(radius));

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = SweepGradient(
        transform: GradientRotation(shimmer * 2 * pi),
        colors: [
          const Color(0xFFFF9EDB).withValues(alpha: 0.75),
          const Color(0xFF9EE8FF).withValues(alpha: 0.75),
          const Color(0xFFFFF3A6).withValues(alpha: 0.65),
          const Color(0xFFC6B3FF).withValues(alpha: 0.75),
          const Color(0xFFFF9EDB).withValues(alpha: 0.75),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, rim);

    // ขอบในสีขาวบางๆ ให้ผิวฟองดูมีความหนา
    canvas.drawRRect(
      rrect.deflate(2.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    final highlight = Rect.fromLTWH(radius * 0.45, size.height * 0.12, min(64, size.width * 0.3), 9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, const Radius.circular(8)),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)],
        ).createShader(highlight),
    );

    canvas.drawCircle(
      Offset(size.width - radius * 0.6, size.height * 0.74),
      2.6,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleSheenPainter oldDelegate) => oldDelegate.shimmer != shimmer;
}
