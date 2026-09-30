import 'package:flutter/material.dart';
import '../../models/submission_model.dart';
import '../../services/submission_service.dart';
import '../../utils/date_format.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/decorated_avatar.dart';
import '../../widgets/pressable_scale.dart';

// หน้าตรวจหลักฐานภารกิจของผู้เล่นคนอื่น (ระบบตรวจสอบภารกิจ 28 ก.ย. 2026 — กติกาดู backend/utils/submissions.js)
// ทีละใบ: รูปหลักฐาน + ชื่อเควส + "ต้องเห็นอะไรในรูป" (Quest Detail) + ผู้ส่ง -> Not approved / Approve
// ผ่าน 2 คน = ผ่าน, ไม่ผ่าน 2 คน = ไม่ผ่าน — แอดมินโหวตครั้งเดียวตัดสินเลย (โชว์ป้ายบอก)
// เข้าได้จากแบนเนอร์ในแท็บ Feed ของ Community และจากหน้า Admin
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _service = SubmissionService();
  List<SubmissionModel> _queue = [];
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _isVoting = false;
  String? _error;
  int _reviewedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final queue = await _service.fetchQueue();
      if (!mounted) return;
      setState(() {
        _queue = queue.submissions;
        _isAdmin = queue.isAdmin;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _vote(bool approve) async {
    if (_queue.isEmpty || _isVoting) return;
    final current = _queue.first;
    setState(() => _isVoting = true);
    try {
      await _service.vote(current.id, approve: approve);
      if (!mounted) return;
      setState(() {
        _queue = _queue.skip(1).toList();
        _reviewedCount += 1;
        _isVoting = false;
      });
      // คิวหมดแล้วลองโหลดใหม่ — ระหว่างตรวจอาจมีคนส่งเข้ามาเพิ่ม
      if (_queue.isEmpty) _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVoting = false);
      showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
      // มีคนตัดสินไปก่อนแล้ว / โหวตไปแล้ว — ข้ามใบนี้ไป
      setState(() => _queue = _queue.skip(1).toList());
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
        title: const Text('Review quests', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.green));
    if (_error != null) {
      return _EmptyReview(
        icon: Icons.cloud_off,
        title: _error!,
        subtitle: 'Pull back and try again',
        onRetry: _load,
      );
    }
    if (_queue.isEmpty) {
      return _EmptyReview(
        icon: Icons.verified_rounded,
        title: _reviewedCount > 0 ? 'Thanks for reviewing!' : 'All caught up',
        subtitle: 'No quests need your review right now',
        onRetry: _load,
      );
    }

    final s = _queue.first;
    return Column(
      children: [
        if (_isAdmin)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Admin — your vote decides right away',
              style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _SubmissionCard(key: ValueKey(s.id), submission: s, remaining: _queue.length),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _VoteButton(
                  label: 'Not approved',
                  icon: Icons.close_rounded,
                  color: Colors.redAccent,
                  filled: false,
                  busy: _isVoting,
                  onPressed: () => _vote(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VoteButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  color: Colors.green,
                  filled: true,
                  busy: _isVoting,
                  onPressed: () => _vote(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final SubmissionModel submission;
  final int remaining;
  const _SubmissionCard({super.key, required this.submission, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final quest = s.quest;
    final user = s.user;
    final what = s.isParty
        ? 'Group photo from a party event'
        : s.isCheckIn
            ? 'Day ${s.checkInDay}/${s.checkInTotal} check-in'
            : 'Quest proof';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ผู้ส่ง
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                DecoratedAvatar(
                  avatarUrl: user?.avatarUrl,
                  size: 36,
                  frameItemType: user?.cosmetics.frame,
                  placeholderBackgroundColor: Colors.grey.shade200,
                  placeholderIconColor: Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'Player',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(formatRelativeTime(s.submittedAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text('$remaining left', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          // รูปหลักฐาน — กดดูเต็มจอ
          GestureDetector(
            onTap: () => _openFullPhoto(context, s.photoUrl),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                s.photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
                      ),
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade200,
                  child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest?.title ?? 'Quest',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                const SizedBox(height: 2),
                Text(what, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (quest != null && quest.detail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Does the photo show this?',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(quest.detail, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.45)),
                ],
                const SizedBox(height: 10),
                Text(
                  // ค้างเกิน 48 ชม. — แอดมินเท่านั้นที่เห็นอันนี้ในคิว (backend/routes/reviews.js)
                  s.escalated
                      ? 'Waited over 48 hours — ${s.approvals} approved, ${s.rejections} not approved. Your call.'
                      : 'Approved ${s.approvals}/${s.approvalsNeeded} so far',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: s.escalated ? Colors.red.shade400 : Colors.grey.shade500,
                    fontWeight: s.escalated ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.pop(dialogContext),
        child: InteractiveViewer(child: Center(child: Image.network(url))),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool busy;
  final VoidCallback onPressed;

  const _VoteButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(26));
    const padding = EdgeInsets.symmetric(vertical: 14);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))],
    );
    return PressableScale(
      child: filled
          ? ElevatedButton(
              onPressed: busy ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: padding,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: busy ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                padding: padding,
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}

class _EmptyReview extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _EmptyReview({required this.icon, required this.title, required this.subtitle, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathingIcon(child: Icon(icon, size: 52, color: Colors.green.shade300)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
