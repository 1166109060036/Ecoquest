import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

// ถือรายการแจ้งเตือนไว้ให้จุดแดงบนไอคอนกระดิ่งกับหน้า Notification ใช้ร่วมกัน
// โหลดครั้งเดียวตอนเข้าแอพ แล้วโหลดใหม่ทุกครั้งที่ทำเควสสำเร็จ (อาจมีแจ้งเตือนใหม่)
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  // นับจากลิสต์ในแอพเอง ไม่ต้องให้ backend ส่งเลขมาแยก
  int get unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _service.fetchNotifications();
    } catch (e) {
      // โหลดแจ้งเตือนไม่ได้ไม่ควรทำให้หน้า Notification พัง — ปล่อยเป็นลิสต์ว่างไปก่อน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // เข้าหน้า Notification แล้วถือว่าอ่านหมด — อัปเดตในเครื่องทันทีไม่ต้องรอโหลดใหม่
  Future<void> markAllRead() async {
    if (unreadCount == 0) return;

    try {
      await _service.markAllRead();
      _items = [
        for (final n in _items)
          NotificationModel(
            id: n.id,
            type: n.type,
            title: n.title,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
          ),
      ];
      notifyListeners();
    } catch (e) {
      // มาร์กอ่านไม่สำเร็จก็แค่ปล่อยจุดแดงค้างไว้ ไม่ต้องรบกวนผู้ใช้ด้วย error
    }
  }
}
