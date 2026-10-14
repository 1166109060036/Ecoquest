import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/org_event_model.dart';
import '../../services/org_service.dart';

// QR เช็คอินเต็มจอสำหรับองค์กร (14 ต.ค. 2026) — เปิดค้างไว้ที่งานให้ผู้เข้าร่วมสแกน
// โค้ดเปลี่ยนทุก 30 วิ (backend/utils/orgQr.js) -> ขอใหม่ตาม expiresInMs ที่ server บอก
// จำนวนคนเช็คอินอัปเดตทุก 5 วิ ให้องค์กรเห็นว่ามีคนสแกนติดแล้ว
class EventQrPage extends StatefulWidget {
  final OrgEventModel event;
  const EventQrPage({super.key, required this.event});

  @override
  State<EventQrPage> createState() => _EventQrPageState();
}

class _EventQrPageState extends State<EventQrPage> {
  final _service = OrgService();
  String? _payload;
  String? _error;
  int _attended = 0;
  DateTime? _expiresAt;
  Timer? _qrTimer;
  Timer? _tick;
  Timer? _countTimer;

  @override
  void initState() {
    super.initState();
    _attended = widget.event.attendedCount;
    _loadQr();
    _countTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadCount());
    // วงนับถอยหลังรอบ QR
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _tick?.cancel();
    _countTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQr() async {
    _qrTimer?.cancel();
    try {
      final qr = await _service.fetchQr(widget.event.id);
      if (!mounted) return;
      setState(() {
        _payload = qr.payload;
        _error = null;
        _expiresAt = DateTime.now().add(Duration(milliseconds: qr.expiresInMs));
      });
      // ขอใหม่หลังหมดรอบนิดหน่อย (เผื่อเวลาเครื่องกับ server ต่างกันเล็กน้อย)
      _qrTimer = Timer(Duration(milliseconds: qr.expiresInMs + 300), _loadQr);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      _qrTimer = Timer(const Duration(seconds: 5), _loadQr); // เน็ตหลุด -> ลองใหม่เรื่อยๆ
    }
  }

  Future<void> _loadCount() async {
    try {
      final e = await _service.fetchEvent(widget.event.id);
      if (mounted) setState(() => _attended = e.attendedCount);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _expiresAt == null ? 0.0 : (_expiresAt!.difference(DateTime.now()).inMilliseconds / 30000).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Check-in QR'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.event.title,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Scan with EcoQuest to get +${widget.event.points} points',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                const SizedBox(height: 24),
                if (_payload != null)
                  QrImageView(
                    data: _payload!,
                    size: 280,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  )
                else
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: Center(
                      child: _error != null
                          ? Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))
                          : const CircularProgressIndicator(color: Colors.green),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: remaining,
                      minHeight: 4,
                      color: Colors.green,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('The code changes every 30 seconds', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                if (_error != null && _payload != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.how_to_reg_rounded, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('$_attended checked in',
                          style: TextStyle(color: Colors.green.shade800, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
