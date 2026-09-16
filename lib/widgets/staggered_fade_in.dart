import 'package:flutter/material.dart';

// ค่อยๆ เลื่อนขึ้น + จางเข้า ตอน widget โผล่มาครั้งแรก — ใช้ได้ทั้งการ์ดเดี่ยวๆ (fridge draft card)
// และลิสต์ที่อยากให้ไล่โผล่ทีละใบ (ใส่ delay ต่างกันทีละ item)
// ยกมาจาก _FadeSlideIn เดิมใน fridge_page.dart แล้วเพิ่ม delay ให้ใช้ร่วมกันได้ทั้งแอพ
//
// ⚠️ ต้อง key ด้วย id ที่เสถียร (ไม่ใช่แค่ index) ตอนใช้ในลิสต์ — ไม่งั้น Flutter อาจ reuse State
// ผิดตัวตอนลิสต์เรียงลำดับใหม่ ทำให้ animation เล่นซ้ำทุก rebuild หรือไม่เล่นเลยตอน item ใหม่แทรกเข้ามา
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 260),
    this.offsetY = 12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _animation.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
