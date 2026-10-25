import 'package:flutter/material.dart';

// เปลี่ยนหน้าแบบเกม (ผู้ใช้ขอ 14 ต.ค. 2026 — "ให้ดูดีขึ้นเหมือนเกม") แทน FadeForwards เดิม
// เข้า: หน้าใหม่เลื่อนขึ้นแบบเด้ง (easeOutBack) + เฟดเข้า / หน้าเดิมที่ถูกทับ: มืดลง
// ⚠️ ห้าม scale ทั้งหน้า (เคยย่อ/ขยาย 92-94%) — GPU ต้องวาดทั้งหน้าใหม่ทุกเฟรม = กระตุก (23 ต.ค. 2026)
// ย้อนกลับ: เล่นกลับด้วย easeIn (ไม่เด้งตอนปิด) / Hero รูปเควสยังบินได้ปกติ
// เครื่องที่เปิดโหมดลดการเคลื่อนไหว -> เฟดอย่างเดียว
class GamePageTransitionsBuilder extends PageTransitionsBuilder {
  const GamePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _GameTransition(animation: animation, secondaryAnimation: secondaryAnimation, child: child);
  }
}

class _GameTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _GameTransition({required this.animation, required this.secondaryAnimation, required this.child});

  @override
  Widget build(BuildContext context) {
    // คิดค่าเส้นโค้งเองในแต่ละเฟรม (ไม่สร้าง CurvedAnimation ใน build — มันเกาะ listener กับ parent แล้วไม่ถูก dispose)
    // ขาเข้าใช้เส้นโค้งเด้ง / ขาออก (reverse) ใช้ easeIn ไม่เด้งตอนปิด
    double curve(Animation<double> a, Curve forward, Curve backward) =>
        (a.status == AnimationStatus.reverse ? backward : forward).transform(a.value.clamp(0.0, 1.0));

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        // หน้าเดิมที่ถูกทับ: มืดลง
        // ⚠️ โครง widget ต้องคงที่ทุกเฟรม (Stack อยู่ตลอด แค่สีโปร่ง 0) — ถ้าเพิ่ม/ถอด Stack ตามค่า u
        // หน้าเดิมจะถูกสร้างใหม่ทั้งหน้า state หาย (ตำแหน่งเลื่อน/ฟอร์มที่กรอกค้าง)
        final u = curve(secondaryAnimation, Curves.easeOutCubic, Curves.easeInCubic);
        final page = Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.35 * u)),
              ),
            ),
          ],
        );
        // หน้าใหม่: เลื่อนขึ้นแบบเด้งเลยจุดนิดนึง + เฟดเข้า
        final fade = curve(animation, const Interval(0, 0.6, curve: Curves.easeOut), Curves.easeIn);
        final slide = curve(animation, Curves.easeOutBack, Curves.easeInCubic);
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 48 * (1 - slide)), child: page),
        );
      },
    );
  }
}
