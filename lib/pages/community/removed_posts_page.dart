import 'package:flutter/material.dart';
import '../../services/submission_service.dart';
import '../../utils/date_format.dart';
import '../../widgets/bubble_toast.dart';

// โพสต์ที่แอดมินถอนรูป/ยึดแต้มไป และยังกู้คืนได้ (ภายใน 7 วัน — backend/routes/reviews.js GET /removed)
// กด Restore = รูปกลับมา + คืนแต้มที่ยึดไป + แจ้งเตือนเจ้าของ (สัญญากับอาจารย์ Bun 21 ต.ค. 2026)
// เข้าจากปุ่มนาฬิกาในหน้า Reported posts
class RemovedPostsPage extends StatefulWidget {
  const RemovedPostsPage({super.key});

  @override
  State<RemovedPostsPage> createState() => _RemovedPostsPageState();
}

class _RemovedPostsPageState extends State<RemovedPostsPage> {
  final _service = SubmissionService();
  List<RemovedPost> _items = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.fetchRemoved();
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

  Future<void> _restore(RemovedPost p) async {
    setState(() => _busyId = p.post.id);
    try {
      final points = await _service.restorePost(p.post.id);
      if (!mounted) return;
      showBubbleToast(context, points > 0 ? 'Restored — $points points given back' : 'Restored — the photo is back');
      setState(() => _items = _items.where((i) => i.post.id != p.post.id).toList());
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Recently removed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: Colors.green,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text('Posts you removed in the last 7 days. Restore brings the photo back and returns any points taken.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.redAccent))
                  else if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Text('Nothing to restore', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    )
                  else
                    for (final p in _items) _card(p),
                ],
              ),
            ),
    );
  }

  Widget _card(RemovedPost p) {
    final s = p.post;
    final revoked = p.action == 'revoke';
    final daysLeft = p.restorableUntil.difference(DateTime.now()).inHours ~/ 24;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: Image.network(
              s.photoUrl,
              width: 96,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 96,
                height: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.quest?.title ?? 'Quest', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(s.user?.displayName ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    revoked ? 'Photo removed · ${s.rewardPoints} points taken back' : 'Photo removed · points kept',
                    style: TextStyle(color: revoked ? Colors.redAccent : Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${p.removedAt != null ? formatRelativeTime(p.removedAt!) : ''} · ${daysLeft < 1 ? 'less than a day' : '$daysLeft days'} left',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busyId == null ? () => _restore(p) : null,
                      icon: _busyId == s.id
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restore'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
