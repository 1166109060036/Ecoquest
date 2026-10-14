import 'package:flutter/material.dart';
import '../../models/org_event_model.dart';
import '../../services/org_service.dart';
import '../../widgets/bubble_toast.dart';

// แอดมินจัดการบัญชีองค์กร (14 ต.ค. 2026) — backend/routes/org.js /admin/*
// Pending: Approve / Reject · Approved: Suspend (ยกเลิกอีเวนต์ที่ยังไม่เริ่ม) · Suspended: Reinstate
class OrgRequestsPage extends StatefulWidget {
  const OrgRequestsPage({super.key});

  @override
  State<OrgRequestsPage> createState() => _OrgRequestsPageState();
}

class _OrgRequestsPageState extends State<OrgRequestsPage> {
  static const _tabs = {'pending': 'Pending', 'approved': 'Approved', 'suspended': 'Suspended', 'rejected': 'Rejected'};

  final _service = OrgService();
  String _status = 'pending';
  List<OrgRequest> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.fetchRequests(_status);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  // reject/suspend ถามเหตุผลสั้นๆ ให้เจ้าของเห็นในแจ้งเตือน
  Future<String?> _askNote(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 300,
          decoration: const InputDecoration(hintText: 'Reason (optional, the organization will see it)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
  }

  Future<void> _decide(OrgRequest r, String action) async {
    String note = '';
    if (action != 'approve') {
      final n = await _askNote(action == 'reject' ? 'Reject ${r.organization.name}?' : 'Suspend ${r.organization.name}?');
      if (n == null) return;
      note = n;
    }
    setState(() => _busyId = r.userId);
    try {
      await _service.decide(r.userId, action, note: note);
      if (!mounted) return;
      showBubbleToast(context, switch (action) { 'approve' => 'Approved', 'reject' => 'Rejected', _ => 'Suspended' });
      await _load();
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organizations')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final t in _tabs.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.value),
                      selected: _status == t.key,
                      onSelected: (_) {
                        setState(() => _status = t.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        if (_error != null)
                          Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                        else if (_items.isEmpty)
                          const Padding(padding: EdgeInsets.all(40), child: Text('Nothing here', textAlign: TextAlign.center))
                        else
                          for (final r in _items) _card(r),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(OrgRequest r) {
    final o = r.organization;
    final busy = _busyId == r.userId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${orgTypeLabels[o.orgType] ?? o.orgType}  ·  ${o.contactEmail}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
            Text('Account: ${r.displayName} (${r.email})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 8),
            Text(o.description),
            if (o.decisionNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Note: ${o.decisionNote}', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            if (busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                children: [
                  if (o.status == 'pending') ...[
                    FilledButton(onPressed: () => _decide(r, 'approve'), child: const Text('Approve')),
                    OutlinedButton(onPressed: () => _decide(r, 'reject'), child: const Text('Reject')),
                  ],
                  if (o.status == 'approved')
                    OutlinedButton(
                      onPressed: () => _decide(r, 'suspend'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Suspend'),
                    ),
                  if (o.status == 'suspended') FilledButton(onPressed: () => _decide(r, 'approve'), child: const Text('Reinstate')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
