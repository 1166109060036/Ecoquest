import 'package:flutter/material.dart';
import '../utils/cosmetics.dart';

// รูปโปรไฟล์วงกลม + กรอบตกแต่ง (ถ้ามีใส่อยู่) — ใช้แทนที่การวาด CircleAvatar ซ้ำๆ ทั้ง 4 จุดใน
// แอพ (หน้าโปรไฟล์ตัวเอง/คนอื่น ผ่าน UserHeader, รายชื่อสมาชิกปาร์ตี้, แท็บเพื่อน, sheet เลือก
// เพื่อนในหน้าแชท) ก่อนหน้านี้ 4 ที่นี้ก๊อปโค้ดวาดอวตารแยกกันเอง ไม่มี widget กลาง
//
// ⚠️ ตอน frameItemType == null ต้องวาดออกมาเหมือนเดิมเป๊ะ (ไม่มีกรอบ ขนาดเท่าเดิม) — ที่มา
// ที่ไปของ placeholder (สี/ไอคอน/ขนาด) ต่างกันในแต่ละจุดเดิมอยู่แล้ว (หน้าโปรไฟล์ใช้โทนมืด
// พื้นหลังรูป, แถวปาร์ตี้/เพื่อนอยู่บนพื้นขาวใช้โทนเทาอ่อน) เลยส่งเป็น parameter แทนที่จะรวมให้
// เหมือนกันหมด — ตั้งใจไม่รวมขนาด/ไอคอน fallback/พฤติกรรมการกดเข้าด้วยกันเกินนี้ กันบานปลาย
class DecoratedAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size; // เส้นผ่านศูนย์กลางรวมทั้งกรอบ (พื้นที่ทั้งหมดที่ widget กิน คงที่ไม่ว่าจะมีกรอบไหม)
  final String? frameItemType; // itemType ของกรอบที่ใส่อยู่ (จาก EquippedCosmetics.frame) — null = ไม่มี
  final Color placeholderBackgroundColor;
  final Color placeholderIconColor;
  final double? placeholderIconSize; // null = คำนวณสัดส่วนจาก size ให้เอง
  final bool showCameraBadge; // true เฉพาะหน้าโปรไฟล์ตัวเองที่แก้รูปได้
  final VoidCallback? onTap;

  const DecoratedAvatar({
    super.key,
    required this.avatarUrl,
    required this.size,
    this.frameItemType,
    this.placeholderBackgroundColor = const Color(0x7A000000), // Colors.black @ 0.48
    this.placeholderIconColor = Colors.white70,
    this.placeholderIconSize,
    this.showCameraBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = cosmeticStyleFor(frameItemType);
    final ringWidth = style?.ringGradient != null ? (style?.ringWidth ?? 3) : 0.0;
    final innerSize = size - ringWidth * 2;
    final iconSize = placeholderIconSize ?? size * 0.53;

    Widget avatar = CircleAvatar(
      radius: innerSize / 2,
      backgroundColor: placeholderBackgroundColor,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      // ยังไม่มีรูป หรือโหลดรูปไม่สำเร็จ (เน็ตหลุด/รูปถูกลบไปแล้ว) -> โชว์ไอคอนคนแทน
      onBackgroundImageError: avatarUrl != null ? (_, _) {} : null,
      child: avatarUrl == null
          ? Icon(Icons.person, color: placeholderIconColor, size: iconSize)
          : null,
    );

    if (ringWidth > 0) {
      avatar = Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: style!.ringGradient,
          boxShadow: style.ringGlowColor != null
              ? [BoxShadow(color: style.ringGlowColor!, blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: avatar,
      );
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (showCameraBadge)
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: Colors.green,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(Icons.photo_camera, size: 13, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
