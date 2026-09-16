import 'package:flutter/material.dart';

// ให้ icon ขยับซูมเข้า-ออกช้าๆ วนซ้ำเบาๆ (breathing) — ใช้กับไอคอนหน้า empty state ทั่วแอพ
// ให้ความรู้สึกว่าแอพยังมีชีวิตอยู่ ไม่ใช่ภาพนิ่งค้างเฉยๆ
class BreathingIcon extends StatefulWidget {
  final Widget child;
  final double minScale;
  final Duration duration;

  const BreathingIcon({
    super.key,
    required this.child,
    this.minScale = 0.94,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<BreathingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)
    ..repeat(reverse: true);
  late final Animation<double> _scale = Tween(begin: widget.minScale, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
