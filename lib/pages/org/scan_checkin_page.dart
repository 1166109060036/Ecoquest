import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/org_event_model.dart';
import '../../models/quest_card_model.dart';
import '../../services/org_service.dart';

class CheckInResult {
  final QuestReward reward;
  final OrgEventModel event;
  const CheckInResult(this.reward, this.event);
}

// สแกน QR ที่องค์กรเปิดบนมือถือที่งาน (14 ต.ค. 2026) — สแกนติดแล้วส่งให้ backend ตรวจทันที
// สำเร็จ = pop กลับพร้อม CheckInResult ให้หน้าที่เปิดมาเล่นเอฟเฟครางวัล (handleQuestCompleted)
// ไม่สำเร็จ = โชว์ข้อความค้างไว้ แล้วสแกนใหม่ได้ (ไม่ยิงโค้ดเดิมซ้ำรัวๆ)
// เลือกรูป QR จากในเครื่องได้ด้วย (ผู้ใช้ขอ 14 ต.ค. 2026 — เช่นกล้องเสีย/ไม่ให้สิทธิ์กล้อง/องค์กรส่ง QR มาในแชท)
// โค้ดใน QR ยังหมดอายุใน ≤ 60 วิเหมือนเดิม รูปเก่าที่เซฟไว้นานแล้วใช้ไม่ได้
class ScanCheckInPage extends StatefulWidget {
  const ScanCheckInPage({super.key});

  @override
  State<ScanCheckInPage> createState() => _ScanCheckInPageState();
}

class _ScanCheckInPageState extends State<ScanCheckInPage> {
  final _service = OrgService();
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  String? _message;
  String? _lastFailedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    // โค้ดเดิมที่เพิ่งไม่ผ่าน — รอ QR บนจอองค์กรเปลี่ยน (ทุก 30 วิ) หรือเล็งใหม่ ไม่ยิงซ้ำ
    if (code == null || code == _lastFailedCode) return;
    await _submit(code);
  }

  // อ่าน QR จากรูปในเครื่อง (ML Kit อ่านจากไฟล์ ไม่ต้องใช้กล้อง)
  Future<void> _pickFromGallery() async {
    if (_busy) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? code;
    try {
      final capture = await _controller.analyzeImage(file.path, formats: const [BarcodeFormat.qrCode]);
      code = capture?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    } catch (_) {
      code = null;
    }
    if (!mounted) return;
    if (code == null) {
      setState(() {
        _busy = false;
        _message = 'No QR code found in this photo. Try a clearer picture.';
      });
      return;
    }
    await _submit(code);
  }

  Future<void> _submit(String code) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await _service.checkIn(code);
      if (!mounted) return;
      Navigator.pop(context, CheckInResult(r.reward, r.event));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastFailedCode = code;
        _message = e.toString().replaceFirst('Exception: ', '');
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to check in'),
        actions: [
          IconButton(
            tooltip: 'Choose a photo',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _busy ? null : _pickFromGallery,
          ),
          IconButton(
            tooltip: 'Flashlight',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'EcoQuest needs camera access to scan the QR code. Allow it in your phone settings.'
                      : 'The camera could not start. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          // กรอบเล็ง
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.greenAccent, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _message != null
                        ? Colors.red.shade700.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _busy
                              ? 'Checking in…'
                              : _message ?? 'Point the camera at the QR code on the organizer\'s phone.',
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose QR photo from gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
