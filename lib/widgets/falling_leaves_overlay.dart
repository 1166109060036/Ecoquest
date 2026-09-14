import 'dart:math';
import 'package:flutter/material.dart';

// เอฟเฟคใบไม้ลอยตกผ่านพื้นหลัง — ใช้กับทุกหน้าที่มีพื้นหลังธีม (background.png + gradient สีดำทับ)
// วางไว้ระหว่าง gradient กับเนื้อหาจริงใน Stack เสมอ (ดูตัวอย่างที่ profile_page.dart) เพื่อให้ใบไม้
// ลอยอยู่หลังการ์ด/ปุ่มต่างๆ ไม่บังตัวหนังสือ และไม่ต้องกังวลเรื่องไปบัง gesture ของเนื้อหาจริง
//
// วาดด้วย CustomPainter ตัวเดียวสำหรับใบไม้ทุกใบในเฟรมเดียว (ไม่ใช้ widget แยกต่อใบไม้ 1 ต้น
// เพราะต้อง rebuild ทุกเฟรมพร้อมกันหมดอยู่แล้ว ทำเป็น widget แยกมีแต่ overhead เพิ่ม)
class FallingLeavesOverlay extends StatefulWidget {
  const FallingLeavesOverlay({super.key});

  @override
  State<FallingLeavesOverlay> createState() => _FallingLeavesOverlayState();
}

class _FallingLeavesOverlayState extends State<FallingLeavesOverlay>
    with SingleTickerProviderStateMixin {
  static const _leafCount = 9;
  // คาบเวลาฐาน (ก่อนคูณ speedFactor ของแต่ละใบ) ที่ใบไม้ตกจากบนจอจนเลยขอบล่างครบ 1 รอบ
  static const _baseCycle = Duration(seconds: 16);

  late final AnimationController _controller;
  late final List<_Leaf> _leaves;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _leaves = List.generate(_leafCount, (_) => _Leaf.random(random));
    _controller = AnimationController(vsync: this, duration: _baseCycle)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer กันไว้อีกชั้น (ปกติแตะทะลุอยู่แล้วเพราะ paint อยู่หลังเนื้อหาจริงใน Stack)
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _LeafPainter(leaves: _leaves, progress: _controller.value),
          );
        },
      ),
    );
  }
}

// พารามิเตอร์สุ่มของใบไม้ 1 ใบ — สุ่มครั้งเดียวตอน initState แล้วคงที่ตลอดชีวิต widget
// ตำแหน่งจริงตอน paint คำนวณจาก progress (0-1 วนซ้ำ) ของ AnimationController ร่วมกับค่าพวกนี้
//
// เก็บ TextPainter ที่ layout() ไว้แล้วในนี้เลย (สร้างครั้งเดียว ใช้ซ้ำทุกเฟรม) ไม่ใช่สร้างใหม่ทุก
// frame ใน paint() เพราะ AnimationController repeat() ทำให้ paint() ถูกเรียกทุกเฟรม (~60 ครั้ง/วินาที)
class _Leaf {
  final double xFraction; // ตำแหน่งแนวนอนคงที่ (0-1 ของความกว้างจอ) ก่อนบวก drift
  final double driftAmplitude; // แกว่งซ้าย-ขวาระหว่างตกกี่พิกเซล (เหมือนใบไม้จริงโดนลมพัด)
  final double phaseOffset; // จุดเริ่มตกไม่พร้อมกัน (0-1) กันใบไม้ตกเรียงแถวเดียวกันหมด
  final double speedFactor; // ใบไหนตกเร็ว/ช้ากว่าใบอื่นเล็กน้อย
  final double rotationSpeed; // ทิศ+ความเร็วการหมุนระหว่างตก
  final TextPainter textPainter;

  _Leaf({
    required this.xFraction,
    required this.driftAmplitude,
    required this.phaseOffset,
    required this.speedFactor,
    required this.rotationSpeed,
    required this.textPainter,
  });

  factory _Leaf.random(Random random) {
    final size = 14.0 + random.nextDouble() * 10;
    final opacity = 0.16 + random.nextDouble() * 0.18;

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.eco.codePoint),
        style: TextStyle(
          fontFamily: Icons.eco.fontFamily,
          package: Icons.eco.fontPackage,
          fontSize: size,
          color: Colors.lightGreen.shade100.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return _Leaf(
      xFraction: random.nextDouble(),
      driftAmplitude: 12 + random.nextDouble() * 22,
      phaseOffset: random.nextDouble(),
      speedFactor: 0.7 + random.nextDouble() * 0.6,
      rotationSpeed: (random.nextBool() ? 1 : -1) * (0.5 + random.nextDouble()),
      textPainter: textPainter,
    );
  }
}

class _LeafPainter extends CustomPainter {
  final List<_Leaf> leaves;
  final double progress;

  _LeafPainter({required this.leaves, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final leaf in leaves) {
      // t วนซ้ำ 0-1 ต่อรอบของใบไม้นี้เอง — คาบต่างกันตาม speedFactor และเริ่มไม่พร้อมกันตาม phaseOffset
      final t = (progress * leaf.speedFactor + leaf.phaseOffset) % 1.0;
      // เริ่มเหนือขอบจอนิดหน่อยและตกเลยขอบล่างนิดหน่อยก่อนวนกลับ กันใบไม้โผล่/หายแบบสะดุดตา
      final y = t * (size.height + 60) - 30;
      final x = leaf.xFraction * size.width + sin(t * 4 * pi) * leaf.driftAmplitude;
      final rotation = t * 2 * pi * leaf.rotationSpeed;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      leaf.textPainter.paint(
        canvas,
        Offset(-leaf.textPainter.width / 2, -leaf.textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) => oldDelegate.progress != progress;
}
