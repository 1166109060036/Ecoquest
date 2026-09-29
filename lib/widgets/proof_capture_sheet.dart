import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'bubble_toast.dart';
import 'pressable_scale.dart';

// รูปหลักฐานที่ผู้ใช้เลือกแล้ว — ส่งต่อให้ QuestProvider.completeQuest / PartyProvider.complete
class ProofPhoto {
  final Uint8List bytes;
  final String contentType; // image/jpeg หรือ image/png (backend รับแค่ 2 แบบนี้)
  const ProofPhoto(this.bytes, this.contentType);
}

// แผ่นถ่ายรูปหลักฐานภารกิจ (ระบบตรวจสอบภารกิจ 28 ก.ย. 2026) — ถ่าย/เลือกรูป -> ดูตัวอย่าง -> "Submit for review"
// ใช้ 2 ที่: Complete เควส solo (หน้า Progress/หน้ารายละเอียด) และหัวหน้าห้องกดจบอีเวนต์ปาร์ตี้ (รูปกลุ่ม)
// คืน null ถ้าผู้ใช้ปิดไปก่อน
//
// ย่อรูปตั้งแต่ตอนถ่าย (maxWidth 1200 / quality 85 แบบรูปในตู้เย็น fridge_page.dart) — ผู้ตรวจดูบนมือถือ
// พอแล้ว และ backend จำกัด 4MB
Future<ProofPhoto?> showProofCaptureSheet(
  BuildContext context, {
  required String title,
  required String hint,
}) {
  return showModalBottomSheet<ProofPhoto>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProofCaptureSheet(title: title, hint: hint),
  );
}

class _ProofCaptureSheet extends StatefulWidget {
  final String title;
  final String hint;
  const _ProofCaptureSheet({required this.title, required this.hint});

  @override
  State<_ProofCaptureSheet> createState() => _ProofCaptureSheetState();
}

class _ProofCaptureSheetState extends State<_ProofCaptureSheet> {
  final _picker = ImagePicker();
  ProofPhoto? _photo;

  Future<void> _pick(ImageSource source) async {
    try {
      final shot = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
      if (shot == null || !mounted) return;
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      // backend รับแค่ image/jpeg กับ image/png — เดาจากนามสกุลไฟล์ (แนวเดียวกับรูปในตู้เย็น)
      final contentType = shot.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() => _photo = ProofPhoto(bytes, contentType));
    } catch (_) {
      if (!mounted) return;
      // เครื่องไม่มีกล้อง / ผู้ใช้ปฏิเสธ permission
      showBubbleToast(context, 'Could not open the camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        // เลื่อนได้ — จอเตี้ย/แนวนอนเนื้อหาสูงเกินพื้นที่ของ bottom sheet (เจอใน widget test ที่จอ 800×600)
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 6),
            Text(widget.hint, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4)),
            const SizedBox(height: 16),
            // ตัวอย่างรูป / กรอบว่างรอถ่าย — สูงไม่เกิน 40% ของจอ ปุ่มด้านล่างจะได้เห็นโดยไม่ต้องเลื่อน
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: photo != null
                      ? Image.memory(photo.bytes, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.photo_camera_outlined, size: 48, color: Colors.grey.shade400),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (photo == null) ...[
              _SheetButton(
                icon: Icons.photo_camera_rounded,
                label: 'Take a photo',
                filled: true,
                onPressed: () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              _SheetButton(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onPressed: () => _pick(ImageSource.gallery),
              ),
            ] else ...[
              _SheetButton(
                icon: Icons.send_rounded,
                label: 'Submit for review',
                filled: true,
                onPressed: () => Navigator.pop(context, photo),
              ),
              const SizedBox(height: 8),
              _SheetButton(
                icon: Icons.refresh_rounded,
                label: 'Retake',
                onPressed: () => setState(() => _photo = null),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Other players will check your photo. You get your reward once it is approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  const _SheetButton({required this.icon, required this.label, required this.onPressed, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
    const padding = EdgeInsets.symmetric(vertical: 13);
    return PressableScale(
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: padding,
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: BorderSide(color: Colors.teal.withValues(alpha: 0.5)),
                padding: padding,
                shape: shape,
              ),
            ),
    );
  }
}
