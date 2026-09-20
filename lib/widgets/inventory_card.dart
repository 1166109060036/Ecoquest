import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'pressable_scale.dart';
import 'pulse_glow.dart';

// การ์ดแถวเดียวใช้ได้ทั้งไอเทม, achievement medal และของในตู้เย็น
// thumbnail ซ้าย + ชื่อ/คำอธิบายขวา
// quantity (ถ้ามี) จะโชว์เป็น badge "xN" มุมล่างซ้ายของ thumbnail แบบกระจกฝ้า (liquid glass)
class InventoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? imageAsset; // รูปจาก assets (ไอเทมตั้งต้นอย่าง Camera/Fridge)
  // ลำดับความสำคัญของรูป: imageBytes > imageFile > imageUrl > imageAsset > icon
  final Uint8List? imageBytes; // รูปที่เพิ่งถ่าย/เลือกแต่ยังไม่ได้ save (พรีวิว draft ของในตู้เย็น)
  final File? imageFile; // ⚠️ ของเก่าที่มีแค่ photoPath ในเครื่อง (ก่อนอัพขึ้น server) — ยังต้องรองรับ
  final String? imageUrl; // รูปที่ save แล้วและอัพขึ้น server จริง (ของในตู้เย็นชิ้นใหม่)
  final String title;
  final String description;
  final Color? descriptionColor; // null = สีเทาปกติ (ใช้สีอื่นตอนอยากเน้น เช่น ของหมดอายุในตู้เย็น)
  final int? quantity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress; // เช่น กดค้างเพื่อลบของในตู้เย็น
  // ปุ่มเล็กๆ ทางขวา (เช่น "Use" สำหรับไอเทม Energy) — มาแทนลูกศร chevron ถ้าใส่มา
  // ไม่ใช้ onTap เพราะ onTap ของการ์ดนี้หมายถึง "กดทั้งการ์ดเพื่อไปหน้าอื่น" คนละความหมายกับ "ใช้ไอเทม"
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionBusy; // true = ปุ่มกดไม่ได้ + โชว์ spinner เล็กๆ แทน (กำลังรอ backend ตอบ)
  final Color actionColor;
  // true ชั่วคราวทันทีหลังซื้อ/ใช้ไอเทมสำเร็จ — เรืองแสงรอบ thumbnail สั้นๆ ให้เห็นชัดว่าการ์ดนี้เพิ่งมีการ
  // เปลี่ยนแปลง (ดู PulseGlow) ผู้เรียกมีหน้าที่เคลียร์กลับเป็น false เองหลังผ่านไปสักพัก
  final bool celebrate;
  // true เฉพาะของตกแต่งโปรไฟล์ที่ใส่อยู่ตอนนี้ — วาดขอบเขียว + เครื่องหมายถูกมุมบนขวาของ thumbnail
  // (ไอเทมทั่วไปไม่มีสถานะนี้ ค่าเริ่มต้น false เลยไม่กระทบการใช้งานเดิมที่จุดอื่น)
  final bool equipped;

  const InventoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = Colors.black87,
    this.imageAsset,
    this.imageBytes,
    this.imageFile,
    this.imageUrl,
    this.descriptionColor,
    this.quantity,
    this.onTap,
    this.onLongPress,
    this.actionLabel,
    this.onAction,
    this.actionBusy = false,
    this.actionColor = Colors.green,
    this.celebrate = false,
    this.equipped = false,
  });

  // รูปจริงจะลอยอยู่บนพื้นโปร่งใสพร้อมเงา ส่วน "ไม่มีรูป" ถึงจะใช้กล่องสีอ่อนรอง icon ไว้
  // (กล่องสีรองมีไว้เป็น placeholder เฉยๆ ถ้าเอามาครอบรูปจริงด้วยจะกลายเป็นกรอบสี่เหลี่ยมทึบ)
  Widget _buildThumbnail() {
    if (imageBytes != null) {
      return _ShadowedImage(image: MemoryImage(imageBytes!), fallback: _iconPlaceholder());
    }
    if (imageFile != null) {
      return _ShadowedImage(image: FileImage(imageFile!), fallback: _iconPlaceholder());
    }
    if (imageUrl != null) {
      return _ShadowedImage(image: NetworkImage(imageUrl!), fallback: _iconPlaceholder());
    }
    if (imageAsset != null) {
      return _ShadowedImage(image: AssetImage(imageAsset!), fallback: _iconPlaceholder());
    }
    return _iconPlaceholder();
  }

  Widget _iconPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: equipped ? Border.all(color: Colors.green, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PulseGlow(
                    active: celebrate,
                    color: actionColor,
                    borderRadius: 16,
                    child: SizedBox(width: 72, height: 72, child: _buildThumbnail()),
                  ),
                  if (equipped)
                    const Positioned(
                      right: -4,
                      top: -4,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                  if (quantity != null)
                    Positioned(
                      left: -6,
                      bottom: -6,
                      // เลเยอร์นอกสุด: รับผิดชอบแค่ drop shadow (ห้ามอยู่ในตัวที่ถูก clip
                      // ไม่งั้น shadow จะโดนตัดหายไปด้วย เพราะ ClipRRect ตัดทุกอย่างรวมถึง
                      // ส่วนที่ควรจะ "ล้น" ออกไปนอกขอบสำหรับ shadow)
                      child: Container(
                        width: 39,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        // เลเยอร์ในสุด: ตัวกระจกฝ้าจริงๆ — clip ให้โค้งมน + เบลอพื้นหลัง
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              alignment: Alignment.center,
                              // D9D9D9 โปร่งใส 80% = เหลือความทึบ 20%
                              color: const Color(0xFFD9D9D9).withValues(alpha: 0.2),
                              child: Text(
                                'x$quantity',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: TextStyle(
                          fontSize: 13,
                          color: descriptionColor ?? Colors.grey.shade600,
                          fontWeight: descriptionColor != null ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ],
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(width: 8),
                PressableScale(
                  child: ElevatedButton(
                    onPressed: actionBusy ? null : onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: actionBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(actionLabel ?? 'Use', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// รูปพื้นหลังโปร่งใส + เงาที่วิ่งตาม "รูปทรงของภาพ" ไม่ใช่เงาสี่เหลี่ยมของกล่อง
// วิธีทำ: ก๊อปรูปเดิมมาย้อมดำทั้งหมด (srcIn เก็บเฉพาะส่วนที่ทึบ) แล้วเบลอ
// วางเหลื่อมลงข้างล่างนิดหน่อย เป็นเงาอยู่ใต้รูปจริงอีกที
// ---------------------------------------------------------------------------
class _ShadowedImage extends StatelessWidget {
  final ImageProvider image;
  final Widget fallback;

  const _ShadowedImage({required this.image, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: const Offset(0, 3),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Image(
              image: image,
              fit: BoxFit.contain,
              color: Colors.black.withValues(alpha: 0.4),
              // โหลดรูปไม่ได้ก็ไม่ต้องมีเงา ปล่อยให้เลเยอร์บนไปโชว์ fallback แทน
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        Image(
          image: image,
          fit: BoxFit.contain,
          // หารูปไม่เจอ (ลืมประกาศใน pubspec / ไฟล์รูปที่ถ่ายไว้ถูกลบไปแล้ว) -> ใช้ icon แทน
          errorBuilder: (_, _, _) => fallback,
        ),
      ],
    );
  }
}
