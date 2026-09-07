import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/fridge_item_model.dart';
import '../../widgets/inventory_card.dart';

// หน้าดูของในตู้เย็น — เข้าจากการกดไอเทม Fridge ในหน้า Inventory
// หน้าตา/ขนาดการ์ดใช้ InventoryCard ตัวเดียวกับหน้า Inventory เลย (ชื่อ + จำนวน + รายละเอียด)
// ต่างกันแค่ช่องรายละเอียดใช้โชว์วันหมดอายุ + เวลาที่เหลือแบบนับถอยหลัง
// TODO: ต่อกับ GET /api/fridge-items จริงตอนมี endpoint — ตอนนี้ใช้ mockFridgeItems
// ไอคอนสำรองตอนของชิ้นนั้นยังไม่มีรูปถ่าย — ใช้ตัวที่สื่อว่าเป็นของกิน
const IconData _foodFallbackIcon = Icons.restaurant;

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // เดินนาฬิกาทุก 1 วินาที เพราะของที่เหลือน้อยกว่า 24 ชม. ต้องโชว์วินาทีถอยหลังจริงๆ
    // (ลิสต์สั้น rebuild ทุกวินาทีไม่หนัก ถ้าอนาคตของเยอะมากค่อยปรับให้ tick ถี่เฉพาะตอนจำเป็น)
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = mockFridgeItems;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // ---- หัวข้อ: ปุ่ม back + ชื่อหน้า (สไตล์เดียวกับหน้า Inventory) ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  const Text('Fridge',
                      style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final expired = item.isExpiredAt(now);

                        return InventoryCard(
                          // ของในตู้เย็นใช้รูปที่ผู้ใช้ถ่ายเองเป็นหลัก
                          // ยังไม่มีรูป (หรือไฟล์หาย) ค่อย fallback เป็นไอคอนอาหาร
                          imageFile: item.photoPath != null ? File(item.photoPath!) : null,
                          icon: _foodFallbackIcon,
                          iconColor: Colors.green,
                          title: item.name,
                          description: _describeExpiry(item, now),
                          // หมดอายุแล้วให้ตัวหนังสือเป็นสีแดง
                          descriptionColor: expired ? Colors.red : null,
                          quantity: item.quantity,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ข้อความบรรทัดรายละเอียด: วันหมดอายุ + เวลาที่เหลือ
// ---------------------------------------------------------------------------
String _describeExpiry(FridgeItemModel item, DateTime now) {
  final date = _formatDate(item.expirationDate);

  if (item.isExpiredAt(now)) {
    return 'Expired ($date)';
  }
  return 'Expires $date · ${_formatRemaining(item.remainingFrom(now))} left';
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

// เหลือเกิน 24 ชม. -> วัน:ชั่วโมง:นาที
// เหลือไม่ถึง 24 ชม. -> ชั่วโมง:นาที:วินาที
String _formatRemaining(Duration remaining) {
  if (remaining.inHours >= 24) {
    return '${remaining.inDays}:'
        '${_twoDigits(remaining.inHours % 24)}:'
        '${_twoDigits(remaining.inMinutes % 60)}';
  }
  return '${_twoDigits(remaining.inHours)}:'
      '${_twoDigits(remaining.inMinutes % 60)}:'
      '${_twoDigits(remaining.inSeconds % 60)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.chevron_left, color: Colors.black54, size: 22),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.kitchen_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Your fridge is empty',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
