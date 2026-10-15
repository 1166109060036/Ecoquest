import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_shell.dart';

// หน้าแรกที่เปิดขึ้นมา ใช้เช็คว่ามี session ค้างอยู่ไหม
// ถ้ามี -> ไป home, ถ้าไม่มี -> ไป login
// หน้าตาแบบหน้าเปิดเกม (14 ต.ค. 2026): พื้นหลังเดียวกับหน้า Login + โลโก้เด้งขยาย + ชื่อแอพค่อยๆ โผล่ + แถบโหลด
// อยู่หน้านี้อย่างน้อย 0.9 วิ ให้แอนิเมชันเล่นจบก่อนเปลี่ยนหน้า (ไม่งั้นแวบเดียวหายเพราะเช็ค session เร็วมาก)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  static const _minShow = Duration(milliseconds: 900);

  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final authProvider = context.read<AuthProvider>();
    await Future.wait([authProvider.checkSession(), Future.delayed(_minShow)]);

    if (!mounted) return;

    if (authProvider.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return AuthScaffold(
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final t = reduce ? 1.0 : _intro.value;
          // โลโก้: 0–60% เด้งขยาย (elasticOut) / ชื่อ+แถบโหลด: 35–100% เฟดขึ้น
          final logo = Curves.elasticOut.transform((t / 0.6).clamp(0.0, 1.0));
          final text = Curves.easeOutCubic.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.3 + 0.7 * logo,
                child: Opacity(
                  opacity: (t / 0.25).clamp(0.0, 1.0),
                  child: const AuthHeader(title: '', subtitle: '', logoSize: 110),
                ),
              ),
              Opacity(
                opacity: text,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - text)),
                  child: Column(
                    children: [
                      const Text(
                        'EcoQuest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Small eco quests, real impact',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            color: Colors.greenAccent,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
