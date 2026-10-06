import 'dart:math' as math;
import 'package:flutter/material.dart';

// เหรียญ Achievement แบบเหรียญจริง (ผู้ใช้สั่ง 6 ต.ค. 2026 — แบบเดิมเป็นแค่ไอคอนในวงกลมใส่ขอบ):
// ริบบิ้นสีหมวดห้อยด้านบน + แผ่นโลหะไล่เฉดแบบสะท้อนแสง (Bronze/Silver/Gold) + ขอบหยักนูน + ประกายครึ่งบน
// + ไอคอนหมวดแบบปั๊มนูนกลางเหรียญ — ใช้ร่วมกันทุกที่ที่โชว์เหรียญ (หน้า Eco Badge, โปรไฟล์ผู้เล่น, dialog ได้เหรียญ)
//
// tier: 'bronze' / 'silver' / 'gold' / null (ยังไม่ได้ = เหรียญเทาจางๆ)
class MedalBadge extends StatelessWidget {
  final IconData icon;
  final String? tier;
  final Color ribbonColor;
  final double size; // ความกว้าง (ความสูงรวมริบบิ้น = size * 1.3)
  final bool showRibbon;

  const MedalBadge({
    super.key,
    required this.icon,
    required this.tier,
    required this.ribbonColor,
    this.size = 64,
    this.showRibbon = true,
  });

  @override
  Widget build(BuildContext context) {
    final metal = _MedalMetal.of(tier);
    final height = showRibbon ? size * 1.3 : size;
    final discCenterY = height - size / 2;

    return Opacity(
      opacity: tier == null ? 0.55 : 1,
      child: SizedBox(
        width: size,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MedalPainter(
                  metal: metal,
                  ribbon: tier == null ? Colors.grey.shade400 : ribbonColor,
                  showRibbon: showRibbon,
                ),
              ),
            ),
            // ไอคอนปั๊มนูน: เงาสว่างเลื่อนลงล่าง + ตัวไอคอนสีเข้มของโลหะ
            Positioned(
              left: 0,
              right: 0,
              top: discCenterY - size * 0.22,
              child: SizedBox(
                height: size * 0.44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, size * 0.018),
                      child: Icon(icon, size: size * 0.36, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    Icon(icon, size: size * 0.36, color: metal.engrave),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ชุดสีโลหะแต่ละขั้น — highlight / base / shade / deep (ขอบมืด) / engrave (สีไอคอนปั๊ม)
class _MedalMetal {
  final Color highlight, base, shade, deep, engrave;
  const _MedalMetal(this.highlight, this.base, this.shade, this.deep, this.engrave);

  static _MedalMetal of(String? tier) => switch (tier) {
        'gold' => const _MedalMetal(
            Color(0xFFFFF4B8), Color(0xFFF2C14E), Color(0xFFC08A22), Color(0xFF7E5610), Color(0xFF8A5E12)),
        'silver' => const _MedalMetal(
            Color(0xFFFFFFFF), Color(0xFFD5DBE2), Color(0xFF9DA8B4), Color(0xFF5E6873), Color(0xFF5E6873)),
        'bronze' => const _MedalMetal(
            Color(0xFFFFD9B3), Color(0xFFD08A4E), Color(0xFF9A5A2A), Color(0xFF5E3313), Color(0xFF6B3A18)),
        _ => const _MedalMetal(
            Color(0xFFF4F4F4), Color(0xFFD6D6D6), Color(0xFFAAAAAA), Color(0xFF7A7A7A), Color(0xFF8A8A8A)),
      };
}

class _MedalPainter extends CustomPainter {
  final _MedalMetal metal;
  final Color ribbon;
  final bool showRibbon;

  _MedalPainter({required this.metal, required this.ribbon, required this.showRibbon});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.48;
    final c = Offset(w / 2, h - w / 2);

    if (showRibbon) _paintRibbon(canvas, w, h);

    // เงาใต้เหรียญ
    canvas.drawCircle(
      c.translate(0, w * 0.03),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );

    // ขอบนอก: ไล่เฉดรอบวง (sweep) ให้ดูเป็นโลหะสะท้อนแสงหลายมุม
    final rimRect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            metal.highlight, metal.base, metal.shade, metal.base,
            metal.highlight, metal.base, metal.shade, metal.base, metal.highlight,
          ],
          transform: const GradientRotation(-math.pi / 4),
        ).createShader(rimRect),
    );

    // ขอบหยัก (ร่องเล็กๆ รอบเหรียญ)
    final tick = Paint()
      ..color = metal.deep.withValues(alpha: 0.35)
      ..strokeWidth = math.max(0.8, w * 0.012)
      ..strokeCap = StrokeCap.round;
    const ticks = 40;
    for (var i = 0; i < ticks; i++) {
      final a = i * 2 * math.pi / ticks;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 0.88), c + dir * (r * 0.97), tick);
    }

    // เส้นขอบนอกสุดเข้มๆ
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.018)
        ..color = metal.deep.withValues(alpha: 0.75),
    );

    // หน้าเหรียญด้านใน: ไล่เฉดแบบแสงตกจากซ้ายบน
    final faceR = r * 0.78;
    final faceRect = Rect.fromCircle(center: c, radius: faceR);
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [metal.highlight, metal.base, metal.shade],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(faceRect),
    );
    // ร่องรอบหน้าเหรียญ: เงาเข้มด้านนอก + เส้นสว่างด้านใน = ดูนูนขึ้นมา
    canvas.drawCircle(
      c,
      faceR + w * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.02)
        ..color = metal.deep.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      c,
      faceR - w * 0.012,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.012)
        ..color = metal.highlight.withValues(alpha: 0.9),
    );

    // ประกายครึ่งบน (ตัดให้อยู่ในหน้าเหรียญ)
    canvas.save();
    canvas.clipPath(Path()..addOval(faceRect));
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-faceR * 0.15, -faceR * 0.55), width: faceR * 1.7, height: faceR * 0.95),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)],
        ).createShader(faceRect),
    );
    canvas.restore();

    // จุดประกายเล็กๆ บนขอบ
    canvas.drawCircle(
      c.translate(-r * 0.55, -r * 0.55),
      w * 0.03,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.015),
    );
  }

  // ริบบิ้นรูปตัว V สองเส้นไขว้กัน ห้อยลงมาหลังเหรียญ
  void _paintRibbon(Canvas canvas, double w, double h) {
    final bottom = h - w * 0.62;
    final dark = Color.lerp(ribbon, Colors.black, 0.28)!;
    final light = Color.lerp(ribbon, Colors.white, 0.18)!;

    Path strip(double topL, double topR, double botL, double botR) => Path()
      ..moveTo(w * topL, 0)
      ..lineTo(w * topR, 0)
      ..lineTo(w * botR, bottom)
      ..lineTo(w * botL, bottom)
      ..close();

    final right = strip(0.60, 0.88, 0.36, 0.64);
    final left = strip(0.12, 0.40, 0.36, 0.64);
    canvas.drawPath(right, Paint()..color = dark);
    canvas.drawPath(
      left,
      Paint()
        ..shader = LinearGradient(colors: [light, ribbon]).createShader(Rect.fromLTWH(0, 0, w, bottom)),
    );
    // แถบขาวกลางริบบิ้น
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = math.max(1, w * 0.035);
    canvas.drawLine(Offset(w * 0.26, 0), Offset(w * 0.50, bottom), stripe);
    canvas.drawLine(Offset(w * 0.74, 0), Offset(w * 0.50, bottom), stripe..color = Colors.white.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.metal != metal || old.ribbon != ribbon || old.showRibbon != showRibbon;
}
