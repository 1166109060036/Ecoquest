import 'package:flutter/material.dart';
import '../../models/org_event_model.dart';
import '../../services/org_service.dart';
import '../../utils/date_format.dart';
import '../../utils/quest_completion.dart';
import '../../widgets/bubble_toast.dart';
import '../../widgets/liquid_glass_dialog.dart';
import '../../widgets/staggered_fade_in.dart';
import 'event_attendees_page.dart';
import 'event_qr_page.dart';
import 'scan_checkin_page.dart';

// รายละเอียดอีเวนต์องค์กร (14 ต.ค. 2026)
// ผู้เล่น: Join / Cancel registration / Scan QR to check in (ตอนเปิดเช็คอิน)
// องค์กรเจ้าของงาน: Show check-in QR / Attendees / Cancel event
class OrgEventDetailPage extends StatefulWidget {
  final OrgEventModel event;

  const OrgEventDetailPage({super.key, required this.event});

  @override
  State<OrgEventDetailPage> createState() => _OrgEventDetailPageState();
}

class _OrgEventDetailPageState extends State<OrgEventDetailPage> {
  final _service = OrgService();
  late OrgEventModel _event = widget.event;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final fresh = await _service.fetchEvent(_event.id);
      if (mounted) setState(() => _event = fresh);
    } catch (_) {
      // โชว์ข้อมูลจากลิสต์ไปก่อน — ปัดลงเพื่อลองใหม่ได้
    }
  }

  Future<void> _run(Future<OrgEventModel> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _event = updated);
      showBubbleToast(context, done);
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action, {Color color = Colors.redAccent}) async {
    final ok = await LiquidGlassDialog.show<bool>(
      context: context,
      icon: Icon(Icons.event_busy_rounded, color: color, size: 28),
      title: title,
      content: Text(message, textAlign: TextAlign.center, style: LiquidGlassDialog.messageStyle),
      actions: [
        LiquidGlassAction(label: 'Back', onPressed: () => Navigator.pop(context, false)),
        LiquidGlassAction(label: action, color: color, onPressed: () => Navigator.pop(context, true)),
      ],
    );
    return ok == true;
  }

  Future<void> _scan() async {
    final result = await Navigator.push<CheckInResult>(
      context,
      MaterialPageRoute(builder: (_) => const ScanCheckInPage()),
    );
    if (result == null || !mounted) return;
    if (result.event.id == _event.id) setState(() => _event = result.event);
    await handleQuestCompleted(context, result.reward, title: 'Event check-in!');
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Event', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: Colors.green,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          // ไล่โผล่ทีละส่วนตอนเปิดหน้า (14 ต.ค. 2026)
          children: staggered([
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(14)),
                  child: Icon(orgEventCategoryIcon(e.category), color: Colors.indigo, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        '${e.org?.name ?? 'Organization'}'
                        '${e.org != null && orgTypeLabels[e.org!.orgType] != null ? '  ·  ${orgTypeLabels[e.org!.orgType]}' : ''}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(label: e.phaseLabel, color: e.phaseColor),
                _Chip(label: orgEventCategoryLabels[e.category] ?? e.category, color: Colors.indigo),
                _Chip(label: '+${e.points} P  ·  +${e.xp} XP', color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(children: [
              _InfoRow(
                icon: Icons.schedule,
                text: '${formatEventDateTime(e.startAt)}\nuntil ${_sameDay(e.startAt, e.endAt) ? _hm(e.endAt) : formatEventDateTime(e.endAt)}',
              ),
              _InfoRow(icon: Icons.place_outlined, text: e.location),
              _InfoRow(icon: Icons.groups, text: '${e.joinedCount} / ${e.capacity} joined${e.isMine ? '  ·  ${e.attendedCount} checked in' : ''}'),
            ]),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('About this event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Text(e.description, style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.45)),
            ],
            const SizedBox(height: 16),
            _InfoCard(
              color: Colors.green.shade50,
              children: [
                Text(
                  e.isMine
                      ? 'At the event, open "Show check-in QR" on your phone. Participants scan it to get their points. '
                          'The code changes every 30 seconds, so a photo of it cannot be shared later.'
                      : 'Come to the event and scan the QR code on the organizer\'s phone to get +${e.points} points. '
                          'Check-in opens 30 minutes before the start and closes 30 minutes after the end.',
                  style: TextStyle(color: Colors.green.shade900, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._actions(e),
          ]),
        ),
      ),
    );
  }

  List<Widget> _actions(OrgEventModel e) {
    if (e.isMine) {
      return [
        _Button(
          label: 'Show check-in QR',
          icon: Icons.qr_code_2_rounded,
          onPressed: e.checkInOpen && !_busy
              ? () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => EventQrPage(event: e)));
                  _reload();
                }
              : null,
          hint: e.checkInOpen ? null : (e.isCancelled || e.isEnded ? null : 'Opens 30 minutes before the start'),
        ),
        const SizedBox(height: 10),
        _Button(
          label: 'Attendees',
          icon: Icons.people_alt_outlined,
          outlined: true,
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => EventAttendeesPage(event: e)));
            _reload();
          },
        ),
        if (e.phase == 'upcoming' && e.attendedCount == 0) ...[
          const SizedBox(height: 10),
          _Button(
            label: 'Cancel event',
            icon: Icons.event_busy_outlined,
            outlined: true,
            danger: true,
            onPressed: _busy
                ? null
                : () async {
                    if (!await _confirm('Cancel this event?',
                        'Everyone who joined will be notified. This cannot be undone.', 'Cancel event')) {
                      return;
                    }
                    await _run(() => _service.cancelEvent(e.id), 'Event cancelled');
                  },
          ),
        ],
      ];
    }

    if (e.hasAttended) {
      return [
        _Button(
          label: 'Checked in${e.myRewardPoints != null ? '  ·  +${e.myRewardPoints} P' : ''}',
          icon: Icons.verified_rounded,
          onPressed: null,
        ),
      ];
    }
    if (e.isCancelled || e.isEnded) {
      return [_Button(label: e.isCancelled ? 'This event was cancelled' : 'This event has ended', onPressed: null)];
    }

    return [
      if (e.checkInOpen) ...[
        _Button(label: 'Scan QR to check in', icon: Icons.qr_code_scanner_rounded, onPressed: _busy ? null : _scan),
        const SizedBox(height: 10),
      ],
      if (!e.isRegistered)
        _Button(
          label: e.isFull ? 'Full' : 'Join event',
          icon: Icons.event_available_outlined,
          outlined: e.checkInOpen,
          onPressed: e.isFull || _busy ? null : () => _run(() => _service.register(e.id), 'You joined this event'),
        )
      else if (e.canCancelRegistration)
        _Button(
          label: 'Cancel my registration',
          icon: Icons.close_rounded,
          outlined: true,
          danger: true,
          onPressed: _busy
              ? null
              : () async {
                  if (!await _confirm('Cancel your registration?', 'You can join again later if there is space.', 'Cancel it')) {
                    return;
                  }
                  await _run(() => _service.unregister(e.id), 'Registration cancelled');
                },
        )
      else
        const _Button(label: 'You joined this event', icon: Icons.check_rounded, onPressed: null),
    ];
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final Color color;
  const _InfoCard({required this.children, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35))),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool danger;
  final String? hint;

  const _Button({required this.label, this.icon, required this.onPressed, this.outlined = false, this.danger = false, this.hint});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Colors.green;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    const padding = EdgeInsets.symmetric(vertical: 14);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        outlined
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: onPressed == null ? Colors.grey.shade300 : color),
                  padding: padding,
                  shape: shape,
                ),
                child: child,
              )
            : ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade700,
                  elevation: 0,
                  padding: padding,
                  shape: shape,
                ),
                child: child,
              ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ],
    );
  }
}
