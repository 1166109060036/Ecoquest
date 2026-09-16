import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

// Pull-to-refresh แบบมีลายเซ็น EcoQuest — ไอคอนใบไม้ (Icons.eco) สีเขียวหมุนแทน spinner เริ่มต้นของ
// Flutter ใช้แทน RefreshIndicator เดิมได้ตรงๆ (หน้าตา API เหมือนกัน: child + onRefresh)
//
// สร้างอยู่บน CustomMaterialIndicator (package custom_refresh_indicator) ซึ่ง reimplement พฤติกรรม/
// physics การดึงจอแบบ native ของแต่ละแพลตฟอร์มไว้ให้ครบแล้ว (จุดที่ทำเองเสี่ยงเรื่อง physics ไม่เนียน
// มากที่สุด) — เราแค่เปลี่ยน indicatorBuilder ให้วาดไอคอนใบไม้แทน RefreshProgressIndicator เริ่มต้น
class LeafRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const LeafRefreshIndicator({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomMaterialIndicator(
      onRefresh: onRefresh,
      backgroundColor: Colors.white,
      indicatorBuilder: (context, controller) => _LeafIndicator(controller: controller),
      child: child,
    );
  }
}

// หมุนตามระยะที่ผู้ใช้ดึงจอ (controller.value) ตอนยังลากอยู่ แต่พอเข้าสถานะ "กำลังโหลดจริง"
// (controller.isLoading) ให้หมุนวนต่อเนื่องแทน เพราะตอนนั้น controller.value นิ่งค้างอยู่ที่ค่าตอน
// armed ไม่ได้ขยับต่อเอง — ถ้าไม่แยกเคสนี้ไอคอนจะหยุดหมุนกลางอากาศระหว่างรอ onRefresh ทำงานจริง
class _LeafIndicator extends StatefulWidget {
  final IndicatorController controller;
  const _LeafIndicator({required this.controller});

  @override
  State<_LeafIndicator> createState() => _LeafIndicatorState();
}

class _LeafIndicatorState extends State<_LeafIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSpin);
  }

  void _syncSpin() {
    if (widget.controller.isLoading && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.controller.isLoading && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSpin);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _spin]),
      builder: (context, _) {
        final angle = widget.controller.isLoading
            ? _spin.value * 2 * pi
            : widget.controller.value.clamp(0.0, 1.0) * 2 * pi;
        return Transform.rotate(angle: angle, child: const Icon(Icons.eco, color: Colors.green));
      },
    );
  }
}
