import 'package:flutter/material.dart';

// กล่องเทาที่ค่อยๆ เพิ่ม/ลด opacity วนซ้ำ (breathing) — ตัวประกอบพื้นฐานของหน้า loading ทุกแบบในแอพ
// ตั้งใจไม่ทำ shimmer sweep (ไล่แสงเฉียงแบบ gradient เคลื่อนที่) เพราะได้ผลลัพธ์ที่ดูทันสมัยใกล้เคียงกัน
// แต่ซับซ้อนกว่ามาก (ต้อง ShaderMask + คำนวณตำแหน่ง gradient เอง) ไม่คุ้มกับสิ่งที่ได้เพิ่มมา
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({super.key, this.width = double.infinity, required this.height, this.borderRadius = 8});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  late final Animation<double> _opacity = Tween(begin: 0.35, end: 0.65).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: _opacity.value * 0.4),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// โครงหน้าตาคร่าวๆ ของ InventoryCard (lib/widgets/inventory_card.dart) — ธัมบ์เนล 72x72 + 2 บรรทัด
// ข้อความ + ปุ่ม action มุมขวา ให้พอเดาได้ว่ากำลังจะโหลดอะไรมา ไม่ใช่วงกลมหมุนเฉยๆ
class InventoryCardSkeleton extends StatelessWidget {
  const InventoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const SkeletonBox(width: 72, height: 72, borderRadius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 180, height: 13),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonBox(width: 60, height: 32, borderRadius: 20),
        ],
      ),
    );
  }
}

// โครงหน้าตาคร่าวๆ ของ QuestCard (lib/widgets/quest_card.dart) — ธัมบ์เนล 64x64 + หัวข้อ + แท็บหมวดหมู่
class QuestCardSkeleton extends StatelessWidget {
  const QuestCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 64, height: 64, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 90, height: 12, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 150, height: 15),
                SizedBox(height: 6),
                SkeletonBox(width: 100, height: 11),
                SizedBox(height: 10),
                SkeletonBox(width: 70, height: 22, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
