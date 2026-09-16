import 'package:flutter/material.dart';
import 'profile_sections.dart' show formatNumber;

// ตัวเลขที่นับไล่ขึ้น (หรือลง) แทนการเปลี่ยนค่าวูบเดียว — ใช้กับ Points/XP ที่อัปเดตหลังทำเควส/ซื้อของ
// จับค่าเก่าไว้ใน didUpdateWidget เป็นจุดเริ่มนับทุกครั้งที่ value เปลี่ยน (ไม่ใช่เริ่มจาก 0 ทุกรอบ)
// เพราะ widget นี้จะถูก rebuild ซ้ำๆ ตาม Provider ทุกครั้งที่ authProvider.refreshProfile() เสร็จ
class CountUpNumber extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String Function(int)? formatter;

  const CountUpNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.formatter,
  });

  @override
  State<CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<CountUpNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);
  late Animation<int> _animation = _buildAnimation(widget.value, widget.value);

  Animation<int> _buildAnimation(int begin, int end) {
    return IntTween(begin: begin, end: end).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant CountUpNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = _buildAnimation(oldWidget.value, widget.value);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(int n) => widget.formatter?.call(n) ?? formatNumber(n);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Text(_format(_animation.value), style: widget.style),
    );
  }
}
