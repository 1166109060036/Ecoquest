import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../utils/date_format.dart';

// หน้า Notification — เข้าจากปุ่มกระดิ่งมุมขวาบนของหน้า Profile
// push ทับ MainShell เลยไม่มี bottom nav ให้เห็น (เหมือนหน้า Settings)
// ข้อมูลจริงจาก GET /api/notifications (โหลดไว้แล้วตั้งแต่ MainShell ให้จุดแดงบนกระดิ่งมีเลขทัน)
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    // เข้ามาดูหน้านี้แล้วถือว่าอ่านหมด — จุดแดงบนกระดิ่งหายทันที
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.items;

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
              child: provider.isLoading && notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : notifications.isEmpty
                      ? _EmptyState(errorMessage: provider.errorMessage)
                      : RefreshIndicator(
                          onRefresh: () => context.read<NotificationProvider>().loadNotifications(),
                          color: Colors.green,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: notifications.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              return _NotificationCard(notification: notifications[index]);
                            },
                          ),
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
// การ์ดแจ้งเตือน 1 ใบ: รูปซ้าย + หัวข้อ/รายละเอียด/เวลาขวา
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 6),
                Text(
                  formatRelativeTime(notification.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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
  final String? errorMessage; // โหลดไม่สำเร็จ (เน็ตหลุด/server ล่ม) — คนละเคสกับ "ยังไม่มีแจ้งเตือน"
  const _EmptyState({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off : Icons.notifications_none_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              failed ? errorMessage! : 'No notifications yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
