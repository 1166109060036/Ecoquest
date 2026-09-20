import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/cosmetics.dart';

// เอฟเฟคอนุภาคลอยผ่านพื้นหลัง — ใช้กับทุกหน้าที่มีพื้นหลังธีม (background.png + gradient สีดำทับ)
// วางไว้ระหว่าง gradient กับเนื้อหาจริงใน Stack เสมอ (ดูตัวอย่างที่ profile_page.dart) เพื่อให้อนุภาค
// ลอยอยู่หลังการ์ด/ปุ่มต่างๆ ไม่บังตัวหนังสือ และไม่ต้องกังวลเรื่องไปบัง gesture ของเนื้อหาจริง
//
// วาดด้วย CustomPainter ตัวเดียวสำหรับอนุภาคทุกตัวในเฟรมเดียว (ไม่ใช้ widget แยกต่ออนุภาค 1 ตัว
// เพราะต้อง rebuild ทุกเฟรมพร้อมกันหมดอยู่แล้ว ทำเป็น widget แยกมีแต่ overhead เพิ่ม)
//
// เดิมไฟล์นี้มีแค่ใบไม้ร่วง (FallingLeavesOverlay) ใช้ฟรีทุกหน้า ตอนนี้กลายเป็นของตกแต่งโปรไฟล์ที่
// ต้องซื้อ (fx_leaves/fx_snow/fx_rain/fx_ember — ดู backend/utils/inventory.js#ITEMS) เฉพาะ 2 หน้า
// โปรไฟล์ (profile_page.dart, player_profile_page.dart) เท่านั้น — อีก 4 หน้า (settings,
// change_password, upgrade_account, create_party) เป็น "ของประดับแอพ" ไม่ใช่ของตกแต่งโปรไฟล์
// เลยยังคงใช้ FallingLeavesOverlay ฟรีเหมือนเดิมทุกอย่างไม่มี regression — ดู alias ท้ายไฟล์นี้
class AmbientOverlay extends StatefulWidget {
  final AmbientEffectType? effect; // null = ไม่แสดงอะไรเลย (ยังไม่ได้ซื้อ/ใส่เอฟเฟกต์ใดๆ)

  const AmbientOverlay({super.key, this.effect});

  @override
  State<AmbientOverlay> createState() => _AmbientOverlayState();
}

class _AmbientOverlayState extends State<AmbientOverlay> with SingleTickerProviderStateMixin {
  static const _particleCount = 9;

  // ⚠️ ต้องมี AnimationController ตัวเดียวตลอดอายุของ State เท่านั้น — เปลี่ยนเอฟเฟกต์แล้วแก้แค่
  // duration พอ ห้าม dispose แล้วสร้างตัวใหม่เด็ดขาด เพราะ SingleTickerProviderStateMixin ยอมให้
  // สร้าง ticker ได้ครั้งเดียว พอสร้างตัวที่ 2 มันจะ assert กลางคันจนการ assign ไม่สำเร็จ ทำให้
  // _controller ค้างชี้ไปที่ตัวที่ dispose ไปแล้ว แล้วไปโดน dispose ซ้ำอีกรอบตอน State ตาย
  // (เคยเป็นบั๊กจริง: หน้า Profile แดงเต็มจอตอนสลับเอฟเฟกต์ครั้งที่ 2 เพราะ build() โยน exception
  // แล้ว ErrorWidget มาแทนทั้ง subtree ซึ่งเป็น Positioned.fill)
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );

  List<_Particle> _particles = const [];
  bool _risesUp = false;

  @override
  void initState() {
    super.initState();
    _syncEffect();
  }

  // เปลี่ยนเอฟเฟกต์ต้องทำที่นี่เท่านั้น ห้ามทำใน build() (การแก้ state ระหว่าง build ผิดหลัก Flutter
  // และเป็นต้นตอของบั๊ก dispose ซ้ำข้างบน)
  @override
  void didUpdateWidget(AmbientOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) _syncEffect();
  }

  void _syncEffect() {
    final effect = widget.effect;
    if (effect == null) {
      // ถอดเอฟเฟกต์ออก — ต้องหยุด controller ด้วย ไม่งั้นมันหมุน repeat() กินซีพียูต่อไปเรื่อยๆ
      // ทั้งที่ build() คืน SizedBox.shrink() ไม่ได้วาดอะไรแล้ว
      _controller.stop();
      _particles = const [];
      return;
    }

    final config = _configFor(effect);
    final random = Random();
    _particles = List.generate(_particleCount, (_) => _Particle.random(random, config));
    _risesUp = config.risesUp;
    _controller
      ..duration = config.baseCycle
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.effect == null) return const SizedBox.shrink();

    // IgnorePointer กันไว้อีกชั้น (ปกติแตะทะลุอยู่แล้วเพราะ paint อยู่หลังเนื้อหาจริงใน Stack)
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
              risesUp: _risesUp,
            ),
          );
        },
      ),
    );
  }
}

class _EffectConfig {
  final IconData icon;
  final Color color;
  final double minSize;
  final double maxSize;
  final double minOpacity;
  final double maxOpacity;
  final bool rotates;
  final bool risesUp; // true = ลอยขึ้น (ไฟ) แทนตกลง (ใบไม้/หิมะ/ฝน)
  final Duration baseCycle;

  const _EffectConfig({
    required this.icon,
    required this.color,
    required this.minSize,
    required this.maxSize,
    required this.minOpacity,
    required this.maxOpacity,
    required this.rotates,
    required this.risesUp,
    required this.baseCycle,
  });
}

_EffectConfig _configFor(AmbientEffectType effect) => switch (effect) {
      AmbientEffectType.leaves => const _EffectConfig(
          icon: Icons.eco,
          color: Color(0xFFC5E8B7), // lightGreen.shade100
          minSize: 14,
          maxSize: 24,
          minOpacity: 0.16,
          maxOpacity: 0.34,
          rotates: true,
          risesUp: false,
          baseCycle: Duration(seconds: 16),
        ),
      AmbientEffectType.snow => const _EffectConfig(
          icon: Icons.ac_unit_rounded,
          color: Colors.white,
          minSize: 10,
          maxSize: 18,
          minOpacity: 0.25,
          maxOpacity: 0.5,
          rotates: false,
          risesUp: false,
          baseCycle: Duration(seconds: 20), // หิมะตกช้ากว่าใบไม้
        ),
      AmbientEffectType.rain => const _EffectConfig(
          icon: Icons.water_drop_rounded,
          color: Color(0xFFB3C7E6),
          minSize: 12,
          maxSize: 18,
          minOpacity: 0.25,
          maxOpacity: 0.45,
          rotates: false,
          risesUp: false,
          baseCycle: Duration(seconds: 6), // ฝนตกเร็วกว่าใบไม้/หิมะมาก
        ),
      AmbientEffectType.ember => const _EffectConfig(
          icon: Icons.circle,
          color: Color(0xFFFFAB70),
          minSize: 5,
          maxSize: 10,
          minOpacity: 0.3,
          maxOpacity: 0.6,
          rotates: false,
          risesUp: true, // ถ่านไฟลอยขึ้น ไม่ใช่ตกลง
          baseCycle: Duration(seconds: 12),
        ),
    };

// พารามิเตอร์สุ่มของอนุภาค 1 ตัว — สุ่มครั้งเดียวตอนสร้างแล้วคงที่ตลอดชีวิต widget
// ตำแหน่งจริงตอน paint คำนวณจาก progress (0-1 วนซ้ำ) ของ AnimationController ร่วมกับค่าพวกนี้
//
// เก็บ TextPainter ที่ layout() ไว้แล้วในนี้เลย (สร้างครั้งเดียว ใช้ซ้ำทุกเฟรม) ไม่ใช่สร้างใหม่ทุก
// frame ใน paint() เพราะ AnimationController repeat() ทำให้ paint() ถูกเรียกทุกเฟรม (~60 ครั้ง/วินาที)
class _Particle {
  final double xFraction; // ตำแหน่งแนวนอนคงที่ (0-1 ของความกว้างจอ) ก่อนบวก drift
  final double driftAmplitude; // แกว่งซ้าย-ขวาระหว่างตก/ลอยขึ้นกี่พิกเซล (เหมือนโดนลมพัด)
  final double phaseOffset; // จุดเริ่มไม่พร้อมกัน (0-1) กันอนุภาคเรียงแถวเดียวกันหมด
  final double speedFactor; // ตัวไหนเร็ว/ช้ากว่าตัวอื่นเล็กน้อย
  final double rotationSpeed; // ทิศ+ความเร็วการหมุน (0 ถ้า config.rotates == false)
  final TextPainter textPainter;

  _Particle({
    required this.xFraction,
    required this.driftAmplitude,
    required this.phaseOffset,
    required this.speedFactor,
    required this.rotationSpeed,
    required this.textPainter,
  });

  factory _Particle.random(Random random, _EffectConfig config) {
    final size = config.minSize + random.nextDouble() * (config.maxSize - config.minSize);
    final opacity =
        config.minOpacity + random.nextDouble() * (config.maxOpacity - config.minOpacity);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(config.icon.codePoint),
        style: TextStyle(
          fontFamily: config.icon.fontFamily,
          package: config.icon.fontPackage,
          fontSize: size,
          color: config.color.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return _Particle(
      xFraction: random.nextDouble(),
      driftAmplitude: 12 + random.nextDouble() * 22,
      phaseOffset: random.nextDouble(),
      speedFactor: 0.7 + random.nextDouble() * 0.6,
      rotationSpeed: config.rotates ? (random.nextBool() ? 1 : -1) * (0.5 + random.nextDouble()) : 0,
      textPainter: textPainter,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool risesUp;

  _ParticlePainter({required this.particles, required this.progress, required this.risesUp});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // t วนซ้ำ 0-1 ต่อรอบของอนุภาคนี้เอง — คาบต่างกันตาม speedFactor และเริ่มไม่พร้อมกันตาม phaseOffset
      final t = (progress * particle.speedFactor + particle.phaseOffset) % 1.0;
      // เริ่มเลยขอบจอนิดหน่อยและออกเลยขอบตรงข้ามนิดหน่อยก่อนวนกลับ กันอนุภาคโผล่/หายแบบสะดุดตา
      final travel = t * (size.height + 60) - 30;
      final y = risesUp ? size.height - travel : travel;
      final x = particle.xFraction * size.width + sin(t * 4 * pi) * particle.driftAmplitude;
      final rotation = t * 2 * pi * particle.rotationSpeed;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      particle.textPainter.paint(
        canvas,
        Offset(-particle.textPainter.width / 2, -particle.textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

// alias ของเดิม — ใบไม้ร่วงฟรีที่ใช้อยู่ใน settings/change_password/upgrade_account/create_party
// (ของประดับแอพ ไม่ใช่ของตกแต่งโปรไฟล์ที่ต้องซื้อ) ยังทำงานเหมือนเดิมทุกอย่างไม่มี regression
class FallingLeavesOverlay extends StatelessWidget {
  const FallingLeavesOverlay({super.key});

  @override
  Widget build(BuildContext context) => const AmbientOverlay(effect: AmbientEffectType.leaves);
}
