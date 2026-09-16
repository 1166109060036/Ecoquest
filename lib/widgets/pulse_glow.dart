import 'package:flutter/material.dart';

// ให้ widget เรืองแสง/pulse สั้นๆ ตอน active เปลี่ยนจาก false -> true — ใช้ทั้งฉลองซื้อของสำเร็จ
// (pulse ครั้งเดียวจบ) และปุ่มปาร์ตี้ที่เพิ่งพร้อมกด (pulse ไม่กี่รอบแล้วหยุด)
//
// ⚠️ ตรวจจับการเปลี่ยนสถานะผ่าน didUpdateWidget (เทียบ oldWidget.active กับ widget.active) ไม่ใช่แค่เช็ค
// widget.active เฉยๆ ตอน build — เพราะถ้า active เป็น true ค้างอยู่ตั้งแต่แรก (ไม่ได้เพิ่งเปลี่ยน)
// ไม่ควร pulse ซ้ำทุกครั้งที่ parent rebuild
class PulseGlow extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color color;
  final int pulseCount;
  final Duration pulseDuration;
  // ใช้กำหนดความโค้งของ "ขอบเรืองแสง" ให้เข้ากับรูปทรงจริงของ child (ปุ่มเหลี่ยม/มน หรือไอคอนวงกลม
  // ก็ตั้งค่านี้ให้ใกล้เคียงกันได้ — ตัวกล่อง glow เองไม่ได้ clip เนื้อหาข้างใน แค่วาดเงาไล่ตามขอบนี้)
  final double borderRadius;

  const PulseGlow({
    super.key,
    required this.child,
    required this.active,
    this.color = Colors.greenAccent,
    this.pulseCount = 2,
    this.pulseDuration = const Duration(milliseconds: 600),
    this.borderRadius = 16,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.pulseDuration);
  late final Animation<double> _glow = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  void _runPulses() async {
    for (int i = 0; i < widget.pulseCount; i++) {
      if (!mounted) return;
      await _controller.forward(from: 0);
      if (!mounted) return;
      await _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant PulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _runPulses();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _glow.value == 0
              ? const []
              : [BoxShadow(color: widget.color.withValues(alpha: 0.55 * _glow.value), blurRadius: 18, spreadRadius: 2 * _glow.value)],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
