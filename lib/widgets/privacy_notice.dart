import 'package:flutter/material.dart';

// กล่องเตือนเรื่องข้อมูลส่วนตัวในรูปหลักฐาน — รูปที่ผ่านการตรวจจะขึ้นฟีดชุมชนให้ทุกคนเห็น
// เคยเจอจริง: ภาพสลิป/ใบเสร็จที่มีชื่อ+เลขบัญชีถูกส่งมาเป็นหลักฐาน (1 ต.ค. 2026)
// ใช้ 2 ที่: ตอนถ่ายรูปส่ง (proof_capture_sheet.dart) และหน้าตรวจ Quest Review (review_page.dart)
class PrivacyNotice extends StatelessWidget {
  final String text;

  const PrivacyNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
