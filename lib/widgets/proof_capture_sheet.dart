import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'bubble_toast.dart';
import 'pressable_scale.dart';
import 'privacy_notice.dart';
import '../models/proof_form.dart';

// รูปหลักฐานที่ผู้ใช้เลือกแล้ว — ส่งต่อให้ QuestProvider.completeQuest / PartyProvider.complete
class ProofPhoto {
  final Uint8List bytes;
  final String contentType; // image/jpeg หรือ image/png (backend รับแค่ 2 แบบนี้)
  // คำตอบฟอร์มเพิ่มเติมของเควส (models/proof_form.dart) — null = เควสไม่มีฟอร์ม
  final ProofDetails? details;
  const ProofPhoto(this.bytes, this.contentType, {this.details});
}

// แผ่นถ่ายรูปหลักฐานภารกิจ (ระบบตรวจสอบภารกิจ 28 ก.ย. 2026) — ถ่าย/เลือกรูป -> ดูตัวอย่าง -> "Submit for review"
// ใช้ 2 ที่: Complete เควส solo (หน้า Progress/หน้ารายละเอียด) และหัวหน้าห้องกดจบอีเวนต์ปาร์ตี้ (รูปกลุ่ม)
// คืน null ถ้าผู้ใช้ปิดไปก่อน
//
// ย่อรูปตั้งแต่ตอนถ่าย: ด้านยาวสุด 960px / quality 70 (~100-200KB ต่อรูป) — ผู้ตรวจดูบนมือถือพอแล้ว
// เล็กกว่ารูปในตู้เย็น (1200/85) เพราะรูปหลักฐานเก็บใน MongoDB และส่งได้ไม่จำกัดต่อวัน ต้องประหยัดที่ (30 ก.ย. 2026)
// ต้องจำกัดทั้ง maxWidth และ maxHeight ไม่งั้นรูปแนวตั้งได้สูงเกิน — backend จำกัด 2MB
// form: ช่องกรอกเพิ่มของเควส (เช่น ส่งคืนอะไร/กี่ชิ้น/ร้านไหน — backend/utils/proofForm.js) null = ส่งแค่รูป
Future<ProofPhoto?> showProofCaptureSheet(
  BuildContext context, {
  required String title,
  required String hint,
  ProofForm? form,
}) {
  return showModalBottomSheet<ProofPhoto>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProofCaptureSheet(title: title, hint: hint, form: form),
  );
}

class _ProofCaptureSheet extends StatefulWidget {
  final String title;
  final String hint;
  final ProofForm? form;
  const _ProofCaptureSheet({required this.title, required this.hint, this.form});

  @override
  State<_ProofCaptureSheet> createState() => _ProofCaptureSheetState();
}

class _ProofCaptureSheetState extends State<_ProofCaptureSheet> {
  final _picker = ImagePicker();
  ProofPhoto? _photo;
  // ---- ฟอร์มเพิ่มเติม ----
  final Set<String> _choices = {};
  int _count = 1;
  final _placeController = TextEditingController();

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  // ส่งได้เมื่อตอบฟอร์มครบ (ต้องเลือกอย่างน้อย 1 อย่างถ้าเควสถาม) — จำนวนเริ่มที่ 1 เสมอ
  bool get _formValid {
    final form = widget.form;
    if (form == null) return true;
    if (form.asksChoices && _choices.isEmpty) return false;
    return true;
  }

  ProofPhoto _withDetails(ProofPhoto photo) {
    final form = widget.form;
    if (form == null) return photo;
    return ProofPhoto(
      photo.bytes,
      photo.contentType,
      details: ProofDetails(
        // ตามลำดับในฟอร์ม ไม่ใช่ลำดับที่กด
        choices: form.choices.where(_choices.contains).toList(),
        count: form.asksCount ? _count : null,
        place: form.asksPlace ? _placeController.text.trim() : null,
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final shot = await _picker.pickImage(source: source, maxWidth: 960, maxHeight: 960, imageQuality: 70);
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
    final form = widget.form;
    return SafeArea(
      child: Padding(
        // ช่องพิมพ์ชื่อร้าน — ดันแผ่นขึ้นเหนือคีย์บอร์ด
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
            const SizedBox(height: 10),
            const PrivacyNotice(
              text: "Don't include personal info such as names, account numbers or receipts. "
                  'Approved photos are shown in the community feed.',
            ),
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
            if (form != null) ...[
              const SizedBox(height: 16),
              _ProofFormFields(
                form: form,
                selected: _choices,
                count: _count,
                placeController: _placeController,
                onToggle: (c) => setState(() => _choices.contains(c) ? _choices.remove(c) : _choices.add(c)),
                onCount: (n) => setState(() => _count = n),
              ),
            ],
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
                label: _formValid ? 'Submit for review' : 'Answer the questions above',
                filled: true,
                onPressed: _formValid ? () => Navigator.pop(context, _withDetails(photo)) : null,
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
      ),
    );
  }
}

// ช่องกรอกเพิ่มตามฟอร์มของเควส: ชิปเลือกได้หลายอัน + ปุ่ม −/+ จำนวน + ช่องพิมพ์สถานที่
class _ProofFormFields extends StatelessWidget {
  final ProofForm form;
  final Set<String> selected;
  final int count;
  final TextEditingController placeController;
  final ValueChanged<String> onToggle;
  final ValueChanged<int> onCount;

  const _ProofFormFields({
    required this.form,
    required this.selected,
    required this.count,
    required this.placeController,
    required this.onToggle,
    required this.onCount,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800);
    final max = form.countMax ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (form.asksChoices) ...[
          Text(form.choiceLabel ?? 'Pick all that apply', style: labelStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in form.choices)
                FilterChip(
                  label: Text(c),
                  selected: selected.contains(c),
                  onSelected: (_) => onToggle(c),
                  selectedColor: Colors.teal.shade50,
                  checkmarkColor: Colors.teal,
                  side: BorderSide(color: selected.contains(c) ? Colors.teal : Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (form.asksCount) ...[
          Row(
            children: [
              Expanded(child: Text(form.countLabel ?? 'How many?', style: labelStyle)),
              IconButton(
                onPressed: count > 1 ? () => onCount(count - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.teal,
                tooltip: 'Less',
              ),
              SizedBox(
                width: 36,
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: count < max ? () => onCount(count + 1) : null,
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.teal,
                tooltip: 'More',
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (form.asksPlace)
          TextField(
            controller: placeController,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: form.placeLabel,
              counterText: '',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

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
