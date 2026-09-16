import 'dart:ui';
import 'package:flutter/material.dart';
import 'pressable_scale.dart';

// Dialog ทรง "Liquid Glass" แบบ macOS — กระจกฝ้าโปร่งแสงที่เบลอทุกอย่างข้างหลังตัวมันเองจริงๆ
// (BackdropFilter) ไม่ใช่แค่พื้นหลังสีขาวโปร่งแสงเฉยๆ ขอบมีเส้นไฮไลท์บางๆ พาดด้านบนจำลองแสงสะท้อนบนผิวกระจก
// ใช้แทน AlertDialog ธรรมดาทุกจุดในแอพที่เป็น popup ยืนยัน/แจ้งเตือน ให้หน้าตาเหมือนกันทั้งแอพ
// (ดูตัวอย่างการใช้งานใน fridge_page.dart, settings_page.dart, party_page.dart, inventory_page.dart,
// camera_page.dart, utils/quest_completion.dart)
class LiquidGlassDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final Widget? content;
  final List<Widget> actions;
  // เอฟเฟคพื้นหลังพิเศษ (เช่น ParticleBurstOverlay ตอนฉลองเลเวลอัพ/ได้เหรียญใหม่) — วาดเป็นชั้นแรกสุด
  // ใน Stack เลยอยู่หลังไอคอน/ข้อความ/ปุ่มเสมอ แต่ยังโดน ClipRRect ของกระจกตัดขอบเหมือนเนื้อหาอื่น
  final Widget? backgroundEffect;

  const LiquidGlassDialog({
    super.key,
    this.icon,
    required this.title,
    this.content,
    this.actions = const [],
    this.backgroundEffect,
  });

  // สไตล์ข้อความเนื้อหามาตรฐาน — ใช้กับ Text ธรรมดาที่ส่งเข้า content ได้เลย
  // ตัวหนังสือขาว + shadow ดำจางๆ ช่วยให้อ่านออกแม้พื้นหลังที่โชว์ทะลุกระจกเข้ามาจะสว่าง/ลายเยอะแค่ไหนก็ตาม
  static const TextStyle messageStyle = TextStyle(
    fontSize: 13.5,
    color: Colors.white,
    height: 1.45,
    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
  );

  // เปิด dialog นี้ — คืนค่าที่ action ส่งกลับมาผ่าน Navigator.pop(context, value) เหมือน showDialog ปกติ
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? icon,
    required String title,
    Widget? content,
    List<Widget> actions = const [],
    Widget? backgroundEffect,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      // ไม่ทำพื้นหลังหน้าเดิมมืดลงตอน dialog เปิด — ให้กระจกใสของ dialog ทำหน้าที่แยกมันออกจากพื้นหลังเอง
      barrierColor: Colors.transparent,
      builder: (context) => LiquidGlassDialog(
        icon: icon,
        title: title,
        content: content,
        actions: actions,
        backgroundEffect: backgroundEffect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ขยายตัวขึ้นมาจากเล็กกว่านิดหน่อย (0.85 -> 1.0) แทนโผล่มาเต็มขนาดทันที — เล่นครั้งเดียวตอน dialog
    // นี้ mount (showDialog เดิมมีแค่ fade อยู่แล้วจาก DialogRoute ของ Flutter เอง ตัวนี้เสริมแค่ scale
    // เข้าไปคู่กัน) ทำที่นี่ที่เดียวเพราะ popup ทุกจุดในแอพเรียกผ่าน LiquidGlassDialog.show() หมดแล้ว
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            // เบลอทุกอย่างที่อยู่ข้างหลัง dialog นี้จริงๆ — หัวใจของเอฟเฟค "กระจกฝ้า" แบบ macOS
            // ⚠️ ตั้งใจเบลอน้อยๆ + โปร่งใสมากๆ (แทนที่จะเบลอจัด+ทึบขาว) ให้รู้สึกเหมือน "กระจกใส" จริงๆ
            // มองทะลุเห็นพื้นหลังชัดเจน ไม่ใช่กระจกฝ้าที่มัวจนแทบไม่เห็นข้างหลัง
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.32),
                      Colors.white.withValues(alpha: 0.14),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 48, offset: const Offset(0, 22)),
                  ],
                ),
                child: Stack(
                  children: [
                    if (backgroundEffect != null) Positioned.fill(child: backgroundEffect!),
                    // เส้นไฮไลท์บางๆ พาดตามขอบบน — จำลองแสงสะท้อนบนผิวกระจกโค้งแบบ liquid glass ของ macOS
                    Positioned(
                      top: 0,
                      left: 24,
                      right: 24,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.9),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[icon!, const SizedBox(height: 14)],
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                            ),
                          ),
                          if (content != null) ...[
                            const SizedBox(height: 10),
                            content!,
                          ],
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                for (int i = 0; i < actions.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(child: actions[i]),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ปุ่ม action ในตัว LiquidGlassDialog — ทรงแคปซูลโปร่งแสงเหมือนปุ่มกระจกใน macOS
// color = null -> ปุ่มรอง (เช่น Cancel) กระจกใสจางๆ ตัวหนังสือสีขาว
// color = ไม่ null -> ปุ่มหลัก/อันตราย fill เต็มด้วยสีนั้น ตัวหนังสือขาวตัวหนา
class LiquidGlassAction extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  const LiquidGlassAction({super.key, required this.label, this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final filled = color != null;
    return PressableScale(
      child: Material(
        color: filled ? color : Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                color: Colors.white,
                shadows: filled ? null : const [Shadow(color: Colors.black45, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
