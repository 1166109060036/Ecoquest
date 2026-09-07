import 'package:flutter/material.dart';
import '../../models/notification_model.dart';

// หน้า Notification — เข้าจากปุ่มกระดิ่งมุมขวาบนของหน้า Profile
// push ทับ MainShell เลยไม่มี bottom nav ให้เห็น (เหมือนหน้า Settings)
// TODO: ต่อกับ backend จริงตอนมี endpoint แจ้งเตือน — ตอนนี้ใช้ mockNotifications
class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = mockNotifications;

    // พื้นหลัง + หัวข้อ + ขนาดการ์ด อิงตามหน้า Inventory/Explore ทั้งหมด ให้หน้าตาเป็นชุดเดียวกัน
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: _TopBar(),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _NotificationCard(notification: notifications[index]);
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
// แถบบนสุด: ปุ่มย้อนกลับ + หัวข้อ "Notification" (ชิดซ้าย ไม่ใช่กึ่งกลาง ตามดีไซน์)
// ขนาด/สีตัวอักษรและปุ่ม back อิงตามหัวข้อในหน้า Inventory เป๊ะๆ
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black54, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Notification',
          style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดแจ้งเตือน 1 ใบ: รูปซ้าย + หัวข้อ/รายละเอียดขวา
// ขนาดทุกอย่าง (padding 16 / มุมโค้ง 20 / เงา / thumbnail 72 / ตัวอักษร 16+13)
// อิงตาม InventoryCard เป๊ะๆ เพื่อให้การ์ดสูงเท่ากับไอเทมในหน้า Inventory
// ต่างกันจุดเดียวคือ thumbnail ที่นี่ไม่มีพื้นหลังสีอ่อนรองและใช้ BoxFit.contain
// เพราะรูปแจ้งเตือนเป็นภาพพื้นหลังโปร่ง ถ้า cover ใส่กรอบสีจะโดนครอปเสียรูป
// ---------------------------------------------------------------------------
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: notification.imageAsset != null
                ? Image.asset(
                    notification.imageAsset!,
                    fit: BoxFit.contain,
                    // ยังไม่มีไฟล์รูป (หรือลืมเพิ่มใน pubspec.yaml) — fallback เป็น icon แทน
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(notification.icon, color: notification.iconColor, size: 36);
                    },
                  )
                : Icon(notification.icon, color: notification.iconColor, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
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
            Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
