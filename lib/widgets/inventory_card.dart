import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// การ์ดแถวเดียวใช้ได้ทั้งไอเทม, achievement medal และของในตู้เย็น
// thumbnail ซ้าย + ชื่อ/คำอธิบายขวา
// quantity (ถ้ามี) จะโชว์เป็น badge "xN" มุมล่างซ้ายของ thumbnail แบบกระจกฝ้า (liquid glass)
class InventoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? imageAsset; // รูปจาก assets (ไอเทมตั้งต้นอย่าง Camera/Fridge)
  final File? imageFile; // รูปที่ผู้ใช้ถ่ายเอง (ของในตู้เย็น) — มาก่อน imageAsset
  final String title;
  final String description;
  final Color? descriptionColor; // null = สีเทาปกติ (ใช้สีอื่นตอนอยากเน้น เช่น ของหมดอายุในตู้เย็น)
  final int? quantity;
  final VoidCallback? onTap;

  const InventoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = Colors.black87,
    this.imageAsset,
    this.imageFile,
    this.descriptionColor,
    this.quantity,
    this.onTap,
  });

  // รูปจริงจะลอยอยู่บนพื้นโปร่งใสพร้อมเงา ส่วน "ไม่มีรูป" ถึงจะใช้กล่องสีอ่อนรอง icon ไว้
  // (กล่องสีรองมีไว้เป็น placeholder เฉยๆ ถ้าเอามาครอบรูปจริงด้วยจะกลายเป็นกรอบสี่เหลี่ยมทึบ)
  Widget _buildThumbnail() {
    if (imageFile != null) {
      return _ShadowedImage(image: FileImage(imageFile!), fallback: _iconPlaceholder());
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
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                  SizedBox(width: 72, height: 72, child: _buildThumbnail()),
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
              if (onTap != null)
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
