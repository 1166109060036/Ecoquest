import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// เอฟเฟคอนุภาคระเบิดออกจากจุดกึ่งกลาง เล่นครั้งเดียวจบ (ไม่วนซ้ำเหมือน FallingLeavesOverlay)
// ใช้ฉลองเหตุการณ์พิเศษ เช่น ทำเควสสำเร็จ / เลเวลอัพ / ปลดล็อกเหรียญ Achievement
//
// วาดด้วย CustomPainter ตัวเดียวเหมือน falling_leaves_overlay.dart (สร้าง TextPainter ของแต่ละอนุภาค
// ครั้งเดียวตอน initState แล้ว paint ซ้ำทุกเฟรมจาก AnimationController ตัวเดียว) ต่างกันแค่วิ่งออกจาก
// จุดศูนย์กลางแทนตกจากบนลงล่าง และเล่นแค่รอบเดียวจบ (forward() ครั้งเดียว ไม่ repeat())
class ParticleBurstOverlay extends StatefulWidget {
  final int particleCount;
  final Color color;
  final Duration duration;
  final VoidCallback? onCompleted;

  const ParticleBurstOverlay({
    super.key,
    this.particleCount = 24,
    this.color = Colors.amber,
    this.duration = const Duration(milliseconds: 900),
    this.onCompleted,
  });

  @override
  State<ParticleBurstOverlay> createState() => _ParticleBurstOverlayState();
}

class _ParticleBurstOverlayState extends State<ParticleBurstOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late final List<_BurstParticle> _particles =
      List.generate(widget.particleCount, (_) => _BurstParticle.random(Random(), widget.color));

  @override
  void initState() {
    super.initState();
    if (widget.onCompleted != null) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onCompleted!();
      });
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(particles: _particles, progress: _controller.value),
        ),
      ),
    );
  }
}

// เปิด overlay ชั่วคราวคลุมทั้งจอผ่าน Overlay.of(context) — ใช้ตรงจุดที่ไม่ใช่ dialog
// (LiquidGlassDialog มี backgroundEffect ของตัวเองอยู่แล้ว ไม่ต้องใช้ตัวนี้)
// ลบตัวเองออกจาก Overlay อัตโนมัติทันทีที่อนุภาคหมดอายุ ไม่ต้องมาคอยเคลียร์เอง
Future<void> showParticleBurst(
  BuildContext context, {
  Color color = Colors.amber,
  int particleCount = 30,
  Duration duration = const Duration(milliseconds: 900),
}) {
  if (!context.mounted) return Future.value();

  final overlay = Overlay.of(context);
  final completer = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: ParticleBurstOverlay(
        color: color,
        particleCount: particleCount,
        duration: duration,
        onCompleted: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

// พารามิเตอร์สุ่มของอนุภาค 1 ตัว — สุ่มครั้งเดียวตอน initState แล้วคงที่ตลอดชีวิต widget
// (เหมือน _Leaf ใน falling_leaves_overlay.dart) ตำแหน่งจริงตอน paint คำนวณจาก progress (0-1 ครั้งเดียว)
class _BurstParticle {
  final double angle; // ทิศที่อนุภาคนี้พุ่งออกไป (เรเดียน)
  final double distance; // ระยะสุดท้ายที่จะไปถึงตอน progress = 1
  final double rotationSpeed;
  final TextPainter textPainter;

  _BurstParticle({
    required this.angle,
    required this.distance,
    required this.rotationSpeed,
    required this.textPainter,
  });

  factory _BurstParticle.random(Random random, Color color) {
    final size = 10.0 + random.nextDouble() * 10;
    final icon = random.nextBool() ? Icons.auto_awesome : Icons.circle;

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return _BurstParticle(
      angle: random.nextDouble() * 2 * pi,
      distance: 60 + random.nextDouble() * 90,
      rotationSpeed: (random.nextBool() ? 1 : -1) * (1 + random.nextDouble() * 2),
      textPainter: textPainter,
    );
  }
}

class _BurstPainter extends CustomPainter {
  final List<_BurstParticle> particles;
  final double progress;

  _BurstPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // พุ่งออกเร็วตอนแรกแล้วช้าลง (ease-out) + จางหายไปช่วงครึ่งหลังของ animation
    final eased = 1 - pow(1 - progress, 3).toDouble();
    final opacity = progress < 0.5 ? 1.0 : (1 - (progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (final particle in particles) {
      final radius = particle.distance * eased;
      final x = center.dx + cos(particle.angle) * radius;
      final y = center.dy + sin(particle.angle) * radius;
      final rotation = progress * 2 * pi * particle.rotationSpeed;

      final glyphSize = particle.textPainter.size;
      // ให้ bounds ของ saveLayer แค่พอดีกับตัวอนุภาค (ไม่ใช้ null) เพราะเรียก saveLayer นี้ทุกอนุภาค
      // ทุกเฟรม — ใส่ bounds แคบๆ ช่วยให้ engine ไม่ต้องคำนวณ/จอง buffer แบบเต็มจอทุกครั้ง
      final bounds = Rect.fromCenter(center: Offset.zero, width: glyphSize.width * 2, height: glyphSize.height * 2);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      // ค่าสีที่ตั้งใน Paint ตรงนี้ไม่มีผลกับสีที่วาดจริง (เอาไว้แค่กำหนด "ความโปร่งของทั้งเลเยอร์"
      // ตอน composite กลับ) — เป็นเทคนิคมาตรฐานเดียวกับที่ widget Opacity ใช้ภายในของ Flutter เอง
      canvas.saveLayer(bounds, Paint()..color = Colors.white.withValues(alpha: opacity));
      particle.textPainter.paint(
        canvas,
        Offset(-particle.textPainter.width / 2, -particle.textPainter.height / 2),
      );
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) => oldDelegate.progress != progress;
}
