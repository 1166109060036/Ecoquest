import 'package:flutter/material.dart';

// ใช้ร่วมกันได้ทุกหน้าหลัก (Home, Inventory, Explore, Party, Profile)
// ส่ง currentIndex เข้ามาว่าตอนนี้อยู่หน้าไหน แล้วมันจะไฮไลต์ให้เอง
// แอนิเมชันแบบเกม (14 ต.ค. 2026): แคปซูลสีเขียวอ่อนขยายออกหลังไอคอนที่เลือก + ไอคอนกระโดดเด้ง (elastic)
// + จุดเล็กใต้ชื่อ — เคารพโหมดลดการเคลื่อนไหว (ไม่เด้ง)
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.inventory_2_rounded, label: 'Inventory'),
    _NavItemData(icon: Icons.explore_rounded, label: 'Explore'),
    _NavItemData(icon: Icons.diversity_3_rounded, label: 'Community'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            return _NavItem(data: _items[index], isActive: index == currentIndex, onTap: () => onTap(index));
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final _NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.data, required this.isActive, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  // เล่นทุกครั้งที่ปุ่มนี้ถูกเลือก: 0 -> 1 = กระโดดขึ้นแล้วตกลงเด้ง
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _NavItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive && !MediaQuery.of(context).disableAnimations) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final color = active ? Colors.green.shade700 : Colors.grey;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              padding: EdgeInsets.symmetric(horizontal: active ? 18 : 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? Colors.green.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _hop,
                builder: (context, child) {
                  final t = _hop.value;
                  // ช่วงแรก 35% = กระโดดขึ้น 7px / ที่เหลือ = ตกลงแบบเด้ง (elasticOut)
                  final up = t < 0.35
                      ? Curves.easeOut.transform(t / 0.35)
                      : 1 - Curves.elasticOut.transform((t - 0.35) / 0.65);
                  final scale = 1 + (active ? 0.12 : 0) + 0.1 * up;
                  return Transform.translate(
                    offset: Offset(0, -7 * up),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                // Icon ไม่ใช่ Text เลยใช้ AnimatedDefaultTextStyle ไล่สีให้ไม่ได้ — ไล่สีด้วย TweenAnimationBuilder ตรงๆ
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, animatedColor, _) => Icon(widget.data.icon, color: animatedColor, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(color: color, fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.normal),
              child: Text(widget.data.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}
