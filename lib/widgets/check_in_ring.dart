import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// วงแหวนเช็คอินของเควสหลายวัน (Food Saver 3/7 Days) — แบ่งเป็นช่องตามจำนวนวัน ช่องที่เช็คอินแล้วเป็นสีเขียว
// ใช้ 3 ที่: วงเล็กในการ์ดหน้า Progress (quest_card.dart), วงใหญ่ในหน้ารายละเอียด (quest_detail_page.dart),
// และการ์ดฉลองตอนกดเช็คอิน (showCheckInCelebration ด้านล่าง)
//
// ค่า done เปลี่ยนเมื่อไหร่ช่องใหม่จะค่อยๆ เติมสีเอง (ไม่ต้องสั่ง) — animateIn: true = ตอนโผล่ครั้งแรกไล่เติมจาก 0
// ครบทุกช่อง (done == total) = วงแหวนเรืองแสงเป็นจังหวะ 2 รอบ
// โหมดลดการเคลื่อนไหวในเครื่อง (MediaQuery.disableAnimations) = เปลี่ยนค่าทันที ไม่มีเติม/เรืองแสง
class CheckInRing extends StatefulWidget {
  final int total;
  final int done;
  final double size;
  final double strokeWidth;
  final bool animateIn;
  final Widget? center;
  // ใส่มา = เริ่มเติมจากค่านี้แทน 0 ตอน animateIn (การ์ดฉลองใช้ ให้เห็นแค่ช่องที่เพิ่งเช็คอินเติมเข้าไป)
  final int? animateFrom;

  const CheckInRing({
    super.key,
    required this.total,
    required this.done,
    this.size = 16,
    this.strokeWidth = 2.5,
    this.animateIn = false,
    this.center,
    this.animateFrom,
  });

  @override
  State<CheckInRing> createState() => _CheckInRingState();
}

class _CheckInRingState extends State<CheckInRing> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  bool get _full => widget.total > 0 && widget.done >= widget.total;

  @override
  void initState() {
    super.initState();
    // เติมจนเต็มแล้วค่อยเรืองแสง — รอให้แอนิเมชันเติมช่องจบก่อน
    if (_full && widget.animateIn) Future.delayed(const Duration(milliseconds: 700), _pulse);
  }

  @override
  void didUpdateWidget(covariant CheckInRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasFull = oldWidget.total > 0 && oldWidget.done >= oldWidget.total;
    if (_full && !wasFull) Future.delayed(const Duration(milliseconds: 700), _pulse);
  }

  Future<void> _pulse() async {
    for (var i = 0; i < 2; i++) {
      if (!mounted) return;
      await _glow.forward(from: 0);
      if (!mounted) return;
      await _glow.reverse();
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final end = widget.done.clamp(0, widget.total).toDouble();
    final begin = widget.animateIn ? (widget.animateFrom ?? 0).toDouble() : end;

    return SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? end : begin, end: end),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => AnimatedBuilder(
          animation: _glow,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              total: widget.total,
              value: value,
              strokeWidth: widget.strokeWidth,
              glow: reduceMotion ? 0 : Curves.easeInOut.transform(_glow.value),
            ),
            child: child,
          ),
        ),
        child: widget.center == null ? null : Center(child: widget.center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int total;
  final double value; // จำนวนช่องที่เติมแล้ว (มีเศษได้ระหว่างแอนิเมชัน)
  final double strokeWidth;
  final double glow; // 0..1

  _RingPainter({required this.total, required this.value, required this.strokeWidth, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    // ช่องว่างระหว่างช่อง — วงเล็กใช้ช่องแคบลงไม่งั้นแทบไม่เหลือเส้น
    final gap = total == 1 ? 0.0 : min(0.14, 2 * pi / total * 0.18);
    final sweep = 2 * pi / total - gap;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.shade300;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.green;

    if (glow > 0) {
      canvas.drawCircle(
        rect.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 2.2
          ..color = Colors.greenAccent.withValues(alpha: 0.55 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.5),
      );
    }

    for (var i = 0; i < total; i++) {
      final start = -pi / 2 + i * (sweep + gap) + gap / 2;
      canvas.drawArc(rect, start, sweep, false, track);
      final f = (value - i).clamp(0.0, 1.0);
      if (f > 0) canvas.drawArc(rect, start, sweep * f, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.glow != glow || old.total != total || old.strokeWidth != strokeWidth;
}

// การ์ดฉลองตอนกดเช็คอินเควสหลายวัน — ขึ้นกลางจอ วงแหวนเติมช่องของวันนี้ แล้วหายไปเอง (แตะเพื่อปิดก่อนได้)
// แทน bubble toast ข้อความ "Day 2/7 checked in" เดิม
// - restarted (ลืมเช็คอินไปวันหนึ่ง) -> วงเหลือช่องเดียว ข้อความสีส้มบอกว่านับใหม่
// - finished (วันสุดท้าย) -> เติมจนครบ + เรืองแสง แล้วปิดเร็วกว่า ให้ผู้เรียกไปต่อที่รางวัล (handleQuestCompleted)
// - pending (ระบบตรวจสอบภารกิจ) -> รูปวันนี้ส่งไปรอตรวจ ข้อความบอกว่า "sent for review" แทน "checked in"
// คืน Future ที่เสร็จตอนการ์ดหายไปแล้ว
Future<void> showCheckInCelebration(
  BuildContext context, {
  required int daysDone,
  required int total,
  bool restarted = false,
  bool finished = false,
  bool pending = false,
}) {
  final overlay = Overlay.of(context);
  final done = Completer<void>();
  late OverlayEntry entry;

  void close() {
    if (done.isCompleted) return;
    entry.remove();
    done.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _CheckInCelebration(
      daysDone: daysDone,
      total: total,
      restarted: restarted,
      finished: finished,
      pending: pending,
      onClose: close,
    ),
  );
  overlay.insert(entry);
  HapticFeedback.lightImpact();
  return done.future;
}

class _CheckInCelebration extends StatefulWidget {
  final int daysDone;
  final int total;
  final bool restarted;
  final bool finished;
  final bool pending;
  final VoidCallback onClose;

  const _CheckInCelebration({
    required this.daysDone,
    required this.total,
    required this.restarted,
    required this.finished,
    required this.pending,
    required this.onClose,
  });

  @override
  State<_CheckInCelebration> createState() => _CheckInCelebrationState();
}

class _CheckInCelebrationState extends State<_CheckInCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _fade.forward();
    // วันสุดท้ายรอให้เรืองแสงครบ 2 รอบก่อน (~2.9 วิ) แล้วค่อยไปต่อที่รางวัล
    _timer = Timer(Duration(milliseconds: widget.finished ? 2900 : 2200), _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _fade.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final Color titleColor;
    if (widget.finished) {
      title = 'All ${widget.total} days done!';
      subtitle = widget.pending ? 'Sent for review — your reward comes once it is approved' : 'Quest complete';
      titleColor = Colors.greenAccent;
    } else if (widget.restarted) {
      title = 'Missed a day';
      subtitle = 'Back to Day 1/${widget.total} — see you tomorrow!';
      titleColor = Colors.orangeAccent;
    } else {
      title = widget.pending
          ? 'Day ${widget.daysDone}/${widget.total} sent for review'
          : 'Day ${widget.daysDone}/${widget.total} checked in';
      subtitle = 'See you tomorrow!';
      titleColor = Colors.white;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _fade, curve: Curves.easeOutBack),
              child: Container(
                width: 230,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckInRing(
                      total: widget.total,
                      done: widget.daysDone,
                      size: 110,
                      strokeWidth: 10,
                      animateIn: true,
                      // นับใหม่ = เริ่มจากว่างเปล่า / ปกติ = เห็นแค่ช่องของวันนี้เติมเข้าไป
                      animateFrom: widget.restarted ? 0 : widget.daysDone - 1,
                      center: Text(
                        '${widget.daysDone}/${widget.total}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
