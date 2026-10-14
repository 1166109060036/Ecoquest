import 'package:flutter/material.dart';
import '../../models/org_event_model.dart';
import '../../services/org_service.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/org_event_card.dart';
import 'create_event_page.dart';
import 'org_event_detail_page.dart';

// หน้าจัดการอีเวนต์ขององค์กร (14 ต.ค. 2026) — ลิสต์อีเวนต์ที่สร้าง + ปุ่มสร้างใหม่
// เข้าได้จาก Settings → My Events (บัญชีองค์กรที่อนุมัติแล้ว)
class MyEventsPage extends StatefulWidget {
  final String orgName;
  const MyEventsPage({super.key, required this.orgName});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  final _service = OrgService();
  List<OrgEventModel> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await _service.fetchMyEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<OrgEventModel>(context, MaterialPageRoute(builder: (_) => const CreateEventPage()));
    if (created == null || !mounted) return;
    showBubbleToast(context, 'Event created');
    _load();
  }

  Future<void> _open(OrgEventModel e) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrgEventDetailPage(event: e)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // กำลังจะมา/กำลังจัดขึ้นก่อน (ใกล้สุดก่อน) แล้วค่อยเป็นที่จบ/ยกเลิกแล้ว (ล่าสุดก่อน)
    final active = _events.where((e) => e.phase == 'upcoming' || e.phase == 'live').toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final past = _events.where((e) => e.phase == 'ended' || e.phase == 'cancelled').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Events', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.orgName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: Colors.green,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('$_error\nPull down to try again',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    )
                  else if (_events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.event_note_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No events yet', style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Tap "New event" to invite players to your activity',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    )
                  else ...[
                    if (active.isNotEmpty) ...[
                      const _Header('Upcoming'),
                      for (final e in active) ...[OrgEventCard(event: e, onTap: () => _open(e)), const SizedBox(height: 10)],
                    ],
                    if (past.isNotEmpty) ...[
                      const _Header('Past'),
                      for (final e in past) ...[OrgEventCard(event: e, onTap: () => _open(e)), const SizedBox(height: 10)],
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
      );
}
