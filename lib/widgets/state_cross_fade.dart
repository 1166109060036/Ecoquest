import 'package:flutter/material.dart';

// เฟดสลับระหว่าง "สถานะ" ของเนื้อหาในหน้า — loading (skeleton) -> ลิสต์ -> ว่าง/error และตอนเปลี่ยนตัวกรอง
// แทนการตัดฉับจากอันหนึ่งเป็นอีกอัน (ผู้ใช้ขอให้แอพสมูทขึ้น 30 ก.ย. 2026)
//
// stateKey = ชื่อสถานะปัจจุบัน (เช่น 'loading' / 'list-Solo' / 'empty') — เปลี่ยนเมื่อไหร่ถึงเฟด ค่าเดิมไม่เฟด
// (ลิสต์โหลดใหม่ข้อมูลเปลี่ยนแต่สถานะเดิมจะไม่กระพริบ) วางทับกันชิดบนระหว่างเฟด ไม่ให้เนื้อหาเด้งกลางจอ
// โหมดลดการเคลื่อนไหวในเครื่อง = สลับทันที
class StateCrossFade extends StatelessWidget {
  final String stateKey;
  final Widget child;
  final Duration duration;

  const StateCrossFade({
    super.key,
    required this.stateKey,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}
