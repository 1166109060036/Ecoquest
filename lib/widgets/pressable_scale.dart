import 'package:flutter/material.dart';

// ห่อ widget ใดๆ ให้ยุบตัวลงเบาๆ ตอนกด แล้วเด้งกลับตอนปล่อยนิ้ว — ใช้กับปุ่มหลักๆ ทั่วแอพ
//
// ⚠️ ใช้ Listener (raw pointer event) แทน GestureDetector โดยตั้งใจ — Listener ไม่เข้าร่วม gesture arena
// เลยไม่แย่ง tap gesture ไปจาก InkWell/ElevatedButton ที่อยู่ข้างใน (child ยังกด/ได้ยินเสียงคลิกผ่าน
// SoundSplashFactory ในไฟล์ sound_service.dart ตามปกติทุกอย่าง) ตัวนี้แค่ "แอบดู" ว่านิ้วกดลง/ยกขึ้น
// เพื่อเอาไปขยับ scale เฉยๆ ไม่ได้ไปยุ่งกับว่าใครเป็นคนรับ tap จริง
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scaleFactor;

  const PressableScale({super.key, required this.child, this.scaleFactor = 0.96});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
