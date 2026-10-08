import 'package:flutter/material.dart';
import '../../models/submission_model.dart';
import '../../services/submission_service.dart';
import '../../utils/date_format.dart';
import '../../widgets/breathing_icon.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/decorated_avatar.dart';
import '../../widgets/liquid_glass_dialog.dart';
import '../../widgets/pressable_scale.dart';

// หน้าโพสต์ที่ถูกรายงาน — แอดมินเท่านั้น (7 ต.ค. 2026 แทนหน้าตรวจหลักฐานเดิม ReviewPage)
// อาจารย์ติงว่าให้ผู้เล่นตรวจทุกอันเป็นภาระ + ไม่มีคนตรวจ = ไม่ได้แต้มจนหมดกำลังใจ -> ส่งรูปแล้วได้แต้มทันที
// ผู้เล่นรายงานโพสต์ที่ดูไม่ได้ทำจริงในฟีด แล้วแอดมินดูเฉพาะอันที่ถูกรายงานที่นี่ ทีละใบ:
//   Keep             = รูปไม่มีปัญหา (ถ้าถูกซ่อนจะกลับมาโชว์)
//   Remove photo     = ถอนรูป (เช่น มีข้อมูลส่วนตัว) แต้มยังอยู่
//   Take back points = รูปไม่ได้แสดงว่าทำเควสจริง -> ถอนรูป + ยึดแต้ม/XP/CO2 คืน (backend/utils/submissions.js)
// เข้าได้จากแบนเนอร์ในแท็บ Feed (แอดมิน) และจากหน้า Admin
class ReportedPostsPage extends StatefulWidget {
  const ReportedPostsPage({super.key});

  @override
  State<ReportedPostsPage> createState() => _ReportedPostsPageState();
}

class _ReportedPostsPageState extends State<ReportedPostsPage> {
  final _service = SubmissionService();
  List<SubmissionModel> _queue = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  int _handledCount = 0;

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
        _error = queue.isAdmin ? null : 'Only an admin can see reported posts';
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

  Future<void> _resolve(String action) async {
    if (_queue.isEmpty || _isBusy) return;
    final current = _queue.first;
    // ยึดแต้มคืนย้อนไม่ได้ — ยืนยันก่อน
    if (action == 'revoke') {
      final ok = await LiquidGlassDialog.show<bool>(
        context: context,
        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 28),
        title: 'Take back the points?',
        content: Text(
          'The photo is removed and ${current.isParty ? 'everyone in the party loses' : '${current.user?.displayName ?? 'the player'} loses'} '
          'the points, XP and CO2 from this quest. This cannot be undone.',
          textAlign: TextAlign.center,
          style: LiquidGlassDialog.messageStyle,
        ),
        actions: [
          LiquidGlassAction(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
          LiquidGlassAction(label: 'Take back', color: Colors.redAccent, onPressed: () => Navigator.pop(context, true)),
        ],
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _isBusy = true);
    try {
      await _service.resolveReport(current.id, action);
      if (!mounted) return;
      showBubbleToast(
        context,
        switch (action) {
          'keep' => 'Kept — the post stays in the feed',
          'remove' => 'Photo removed — points kept',
          _ => 'Photo removed and points taken back',
        },
      );
    } catch (e) {
      // แอดมินอีกเครื่องจัดการไปแล้ว — ข้ามใบนี้ไป
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (!mounted) return;
    setState(() {
      _queue = _queue.skip(1).toList();
      _handledCount += 1;
      _isBusy = false;
    });
    // หมดแล้วลองโหลดใหม่ — ระหว่างนี้อาจมีรายงานเข้ามาเพิ่ม
    if (_queue.isEmpty) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Reported posts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.green));
    if (_error != null) {
      return _EmptyReports(icon: Icons.cloud_off, title: _error!, subtitle: 'Pull back and try again', onRetry: _load);
    }
    if (_queue.isEmpty) {
      return _EmptyReports(
        icon: Icons.verified_rounded,
        title: _handledCount > 0 ? 'All reports handled' : 'All clear',
        subtitle: 'No reported posts right now',
        onRetry: _load,
      );
    }

    final s = _queue.first;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _ReportedCard(key: ValueKey(s.id), submission: s, remaining: _queue.length),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Keep',
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      busy: _isBusy,
                      onPressed: () => _resolve('keep'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Remove photo',
                      icon: Icons.hide_image_outlined,
                      color: Colors.orange.shade800,
                      busy: _isBusy,
                      onPressed: () => _resolve('remove'),
                    ),
                  ),
                ],
              ),
              // ของเก่าก่อน 7 ต.ค. 2026 ไม่มีบันทึกการให้แต้ม — ยึดคืนไม่ได้ ถอนรูปได้อย่างเดียว
              if (s.canRevoke) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _ActionButton(
                    label: 'Not a real quest — take back points',
                    icon: Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent,
                    filled: true,
                    busy: _isBusy,
                    onPressed: () => _resolve('revoke'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportedCard extends StatelessWidget {
  final SubmissionModel submission;
  final int remaining;
  const _ReportedCard({super.key, required this.submission, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final quest = s.quest;
    final user = s.user;
    final what = s.isParty
        ? 'Group photo from a party event'
        : s.isCheckIn
            ? 'Day ${s.checkInDay}/${s.checkInTotal} check-in'
            : 'Quest photo';

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
          // รูป — กดดูเต็มจอ
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
                // เหตุผลที่ถูกรายงาน + จำนวน
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in s.reportReasons.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text('${reportReasonLabels[entry.key] ?? entry.key} · ${entry.value}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.orange.shade900)),
                      ),
                    if (s.hiddenByReports)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Hidden from the feed',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(quest?.title ?? 'Quest',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                const SizedBox(height: 2),
                Text(
                  s.rewardPoints > 0 ? '$what · earned +${s.rewardPoints} P' : what,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (quest != null && quest.detail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Does the photo show this?',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(quest.detail, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.45)),
                ],
                // ข้อมูลที่ผู้ส่งกรอกตามฟอร์มของเควส (เช่น ส่งคืนอะไร/กี่ชิ้น/ร้านไหน)
                if (s.details != null && s.details!.summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 18, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('They reported: ${s.details!.summary}',
                              style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.teal.shade900)),
                        ),
                      ],
                    ),
                  ),
                ],
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(26));
    const padding = EdgeInsets.symmetric(vertical: 13, horizontal: 8);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
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

class _EmptyReports extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const _EmptyReports({required this.icon, required this.title, required this.subtitle, required this.onRetry});

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
