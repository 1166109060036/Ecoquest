import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// เอฟเฟค "รางวัลลอยเข้ากระเป๋า" ตอนจบเควส — ป้ายรางวัลโผล่ด้านบนจอ แล้วเหรียญทอง (Points) กับใบไม้เขียว (XP)
// พุ่งออกจาก origin (กลางจอถ้าไม่ส่งมา) โค้งลอยเข้าไปในป้ายทีละอัน ป้ายเด้งทุกครั้งที่ของเข้า และตัวเลขนับขึ้น
// ตามจำนวนที่เข้าไปแล้ว จากนั้นป้ายค้างไว้ครู่หนึ่งแล้วลอยหายขึ้นไป
//
// ใช้แทน bubble toast + particle burst เดิมใน handleQuestCompleted() — ป้ายนี้บอกทั้ง "จบเควส" และ "ได้เท่าไหร่"
// ในตัวแล้ว ใส่ทั้งหมดพร้อมกันจอจะรก
//
// คืน Future ที่เสร็จตอนของ "ลงป้ายครบแล้ว" (ไม่ใช่ตอนป้ายหายไป) ให้ผู้เรียกรอก่อนเปิด popup เหรียญ/เลเวลอัพ
// ได้ ไม่งั้น popup จะเปิดทับตอนของยังบินอยู่
//
// ผู้ใช้เปิดโหมดลดการเคลื่อนไหวในเครื่อง (MediaQuery.disableAnimations) -> ไม่มีของบิน โชว์ป้ายพร้อมตัวเลขเต็มเลย
VoidCallback? _activeDismiss;

Future<void> showRewardFly(
  BuildContext context, {
  required int points,
  required int xp,
  Offset? origin,
  String title = 'Quest complete!',
}) {
  _activeDismiss?.call();

  final overlay = Overlay.of(context);
  final landed = Completer<void>();
  late OverlayEntry entry;
  var removed = false;

  entry = OverlayEntry(
    builder: (_) => _RewardFly(
      points: points,
      xp: xp,
      origin: origin,
      title: title,
      onLanded: () {
        if (!landed.isCompleted) landed.complete();
      },
      onDone: () {
        if (removed) return;
        removed = true;
        entry.remove();
        if (!landed.isCompleted) landed.complete();
      },
      registerDismiss: (dismiss) => _activeDismiss = dismiss,
    ),
  );
  overlay.insert(entry);
  return landed.future;
}

class _RewardFly extends StatefulWidget {
  final int points;
  final int xp;
  final Offset? origin;
  final String title;
  final VoidCallback onLanded;
  final VoidCallback onDone;
  final ValueChanged<VoidCallback> registerDismiss;

  const _RewardFly({
    required this.points,
    required this.xp,
    required this.origin,
    required this.title,
    required this.onLanded,
    required this.onDone,
    required this.registerDismiss,
  });

  @override
  State<_RewardFly> createState() => _RewardFlyState();
}

// ของที่บิน 1 ชิ้น — เวลาทั้งหมดเป็นสัดส่วนของ controller (0..1)
class _Coin {
  final bool isPoints; // true = เหรียญทองเข้าฝั่ง Points, false = ใบไม้เขียวเข้าฝั่ง XP
  final double start; // เริ่มบิน
  final double end; // ถึงป้าย
  final Offset spread; // พุ่งออกไปทางไหนก่อนโค้งกลับเข้าป้าย (ให้แต่ละชิ้นไม่บินทับเส้นเดียวกัน)

  _Coin(this.isPoints, this.start, this.end, this.spread);

  double progress(double t) => ((t - start) / (end - start)).clamp(0.0, 1.0);
  bool arrived(double t) => t >= end;
}

class _RewardFlyState extends State<_RewardFly> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2600);
  static const _pillWidth = 230.0;
  static const _pillHeight = 58.0;
  // ช่วงเวลา (สัดส่วนของ _total): ป้ายโผล่ 0-0.12 / ของบิน 0.08-0.62 / ค้าง / ป้ายลอยหาย 0.82-1
  static const _flyFrom = 0.08;
  static const _flyDuration = 0.26;
  static const _flyStagger = 0.03;
  static const _leaveFrom = 0.82;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _total);
  late final List<_Coin> _coins;
  late final double _landedAt;
  var _reportedLanding = false;

  @override
  void initState() {
    super.initState();
    widget.registerDismiss(_dismiss);

    // เหรียญ/ใบไม้ฝั่งละ 5 ชิ้น สลับกันออก — ฝั่งที่รางวัลเป็น 0 ไม่ต้องมีของบิน
    final rng = Random();
    final kinds = <bool>[
      for (var i = 0; i < 5; i++) ...[
        if (widget.points > 0) true,
        if (widget.xp > 0) false,
      ],
    ];
    _coins = [
      for (var i = 0; i < kinds.length; i++)
        _Coin(
          kinds[i],
          _flyFrom + i * _flyStagger,
          _flyFrom + i * _flyStagger + _flyDuration,
          Offset((rng.nextDouble() - 0.5) * 220, -40 - rng.nextDouble() * 90),
        ),
    ];
    _landedAt = _coins.isEmpty ? _flyFrom : _coins.map((c) => c.end).reduce(max);

    _controller.addListener(_checkLanded);
    _controller.forward().whenComplete(widget.onDone);
  }

  void _checkLanded() {
    if (_reportedLanding || _controller.value < _landedAt) return;
    _reportedLanding = true;
    HapticFeedback.lightImpact();
    widget.onLanded();
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.stop();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final size = media.size;
    final pillTop = media.padding.top + 12;
    // +7 = แถวตัวเลขอยู่ครึ่งล่างของป้าย (ครึ่งบนเป็นหัวข้อ "Quest complete!")
    final valuesRow = Offset(size.width / 2, pillTop + _pillHeight / 2 + 7);
    // ของบินเข้าตรงตัวเลขของฝั่งนั้นๆ (ซ้าย = Points, ขวา = XP) — มีฝั่งเดียวตัวเลขอยู่กลางป้าย
    final bothSides = widget.points > 0 && widget.xp > 0;
    final pointsTarget = bothSides ? valuesRow + const Offset(-_pillWidth / 4, 0) : valuesRow;
    final xpTarget = bothSides ? valuesRow + const Offset(_pillWidth / 4, 0) : valuesRow;
    final origin = widget.origin ?? Offset(size.width / 2, size.height * 0.55);

    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = reduceMotion ? max(_controller.value, _landedAt) : _controller.value;

            // ตัวเลขในป้าย = สัดส่วนของที่ลงแล้วของฝั่งนั้น
            int shown(bool isPoints, int total) {
              final side = _coins.where((c) => c.isPoints == isPoints).toList();
              if (side.isEmpty) return total;
              final arrived = side.where((c) => c.arrived(t)).length;
              return (total * arrived / side.length).round();
            }

            // ป้ายเด้งสั้นๆ ทุกครั้งที่มีของลง
            var bump = 0.0;
            for (final c in _coins) {
              final since = t - c.end;
              if (since >= 0 && since < 0.05) bump = max(bump, sin(since / 0.05 * pi));
            }

            final enter = Curves.easeOutBack.transform((t / 0.12).clamp(0.0, 1.0));
            final leave = Curves.easeIn.transform(((t - _leaveFrom) / (1 - _leaveFrom)).clamp(0.0, 1.0));
            final pillOpacity = (enter.clamp(0.0, 1.0) * (1 - leave)).clamp(0.0, 1.0);

            return Stack(
              children: [
                Positioned(
                  left: (size.width - _pillWidth) / 2,
                  top: pillTop - leave * 30,
                  width: _pillWidth,
                  height: _pillHeight,
                  child: Opacity(
                    opacity: pillOpacity,
                    child: Transform.scale(
                      scale: (0.7 + 0.3 * enter) * (1 + 0.07 * bump),
                      child: _RewardPill(
                        title: widget.title,
                        points: shown(true, widget.points),
                        xp: shown(false, widget.xp),
                        showPoints: widget.points > 0,
                        showXp: widget.xp > 0,
                      ),
                    ),
                  ),
                ),
                if (!reduceMotion)
                  for (final c in _coins)
                    if (t >= c.start && !c.arrived(t))
                      _flyingCoin(c, c.progress(t), origin, c.isPoints ? pointsTarget : xpTarget),
              ],
            );
          },
        ),
      ),
    );
  }

  // เส้นทางโค้ง (quadratic bezier): origin -> จุดที่พุ่งออกไปก่อน (spread) -> เป้าในป้าย
  // เร่งความเร็วตอนใกล้ถึง (easeInCubic) ให้รู้สึกว่า "ถูกดูดเข้าไป"
  Widget _flyingCoin(_Coin c, double p, Offset from, Offset to) {
    final e = Curves.easeInCubic.transform(p);
    final control = from + c.spread;
    final pos = from * pow(1 - e, 2).toDouble() + control * (2 * (1 - e) * e) + to * (e * e);
    // โผล่แบบขยายขึ้นตอนเริ่ม แล้วหดลงนิดตอนเข้าป้าย
    final scale = p < 0.15 ? p / 0.15 : 1 - 0.35 * ((p - 0.6) / 0.4).clamp(0.0, 1.0);
    const size = 22.0;

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Transform.scale(
        scale: scale,
        child: Icon(
          c.isPoints ? Icons.stars_rounded : Icons.eco_rounded,
          size: size,
          color: c.isPoints ? Colors.amber : Colors.lightGreenAccent.shade400,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  final String title;
  final int points;
  final int xp;
  final bool showPoints;
  final bool showXp;

  const _RewardPill({
    required this.title,
    required this.points,
    required this.xp,
    required this.showPoints,
    required this.showXp,
  });

  // FittedBox ย่อทั้งแถวลงเองถ้าตัวเลขยาวเกินครึ่งป้าย (เช่นรางวัลหลักร้อยตอนมีบัฟ Energy) — ไม่ให้ล้น
  Widget _value(IconData icon, Color color, String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(29),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (showPoints)
                Expanded(child: Center(child: _value(Icons.stars_rounded, Colors.amber, '+$points P'))),
              if (showXp)
                Expanded(
                  child: Center(child: _value(Icons.eco_rounded, Colors.lightGreenAccent.shade400, '+$xp XP')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
