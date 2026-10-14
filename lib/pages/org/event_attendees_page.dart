import 'package:flutter/material.dart';
import '../../models/org_event_model.dart';
import '../../services/org_service.dart';
import '../../utils/date_format.dart';
import '../../widgets/decorated_avatar.dart';

// รายชื่อผู้ลงทะเบียน + ใครเช็คอินแล้ว (องค์กรเจ้าของงานเท่านั้น) — เช็คอินแล้วขึ้นก่อน
class EventAttendeesPage extends StatefulWidget {
  final OrgEventModel event;
  const EventAttendeesPage({super.key, required this.event});

  @override
  State<EventAttendeesPage> createState() => _EventAttendeesPageState();
}

class _EventAttendeesPageState extends State<EventAttendeesPage> {
  final _service = OrgService();
  List<OrgAttendee> _attendees = [];
  late OrgEventModel _event = widget.event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _service.fetchAttendees(widget.event.id);
      if (!mounted) return;
      setState(() {
        _attendees = r.attendees;
        _event = r.event;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Attendees'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: Colors.green,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(_event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${_event.attendedCount} checked in  ·  ${_event.joinedCount} / ${_event.capacity} joined',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.redAccent))
                  else if (_attendees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('No one has joined yet', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    )
                  else
                    for (final a in _attendees)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            DecoratedAvatar(
                              avatarUrl: a.avatarUrl,
                              size: 38,
                              placeholderBackgroundColor: Colors.grey.shade300,
                              placeholderIconColor: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    a.attended && a.attendedAt != null
                                        ? 'Checked in ${formatRelativeTime(a.attendedAt!)}'
                                        : 'Lv. ${a.level}  ·  joined',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              a.attended ? Icons.check_circle_rounded : Icons.schedule_rounded,
                              color: a.attended ? Colors.green : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
