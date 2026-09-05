import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// การ์ดแถวเดียวใช้ได้ทั้งไอเทมและ achievement medal — thumbnail ซ้าย + ชื่อ/คำอธิบายขวา
// quantity (ถ้ามี) จะโชว์เป็น badge "xN" มุมล่างซ้ายของ thumbnail แบบกระจกฝ้า (liquid glass)
class InventoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? imageAsset; // ถ้ามี ใช้รูปนี้แทน icon
  final String title;
  final String description;
  final int? quantity;
  final VoidCallback? onTap;

  const InventoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = Colors.black87,
    this.imageAsset,
    this.quantity,
    this.onTap,
  });

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
                color: Colors.black.withOpacity(0.06),
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
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: imageAsset != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              imageAsset!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // ยังไม่เจอไฟล์รูป (เช่น ลืมเพิ่มใน pubspec.yaml) — fallback เป็น icon แทน
                                return Icon(icon, color: iconColor, size: 36);
                              },
                            ),
                          )
                        : Icon(icon, color: iconColor, size: 36),
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
                              color: Colors.black.withOpacity(0.5),
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
                              color: const Color(0xFFD9D9D9).withOpacity(0.2),
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
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
