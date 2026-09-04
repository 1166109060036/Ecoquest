import 'package:flutter/material.dart';

// ใช้ร่วมกันได้ทุกหน้าหลัก (Home, Inventory, Explore, Party, Profile)
// ส่ง currentIndex เข้ามาว่าตอนนี้อยู่หน้าไหน แล้วมันจะไฮไลต์ให้เอง
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.inventory_2_rounded, label: 'Inventory'),
    _NavItemData(icon: Icons.explore_rounded, label: 'Explore'),
    _NavItemData(icon: Icons.groups_rounded, label: 'Party'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            final isActive = index == currentIndex;
            final item = _items[index];
            final color = isActive ? Colors.green : Colors.grey;

            return InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: color, size: 24),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
