import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';

// ถือรายการแจ้งเตือนไว้ให้จุดแดงบนไอคอนกระดิ่งกับหน้า Notification ใช้ร่วมกัน
// โหลดครั้งเดียวตอนเข้าแอพ แล้วโหลดใหม่ทุกครั้งที่ทำเควสสำเร็จ (อาจมีแจ้งเตือนใหม่)
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  // เก็บ id ที่เคยเห็นแล้ว ไว้เทียบว่ารอบนี้มีแจ้งเตือนใหม่จริงๆ โผล่มาไหม (กันเล่นเสียงซ้ำตอนแค่โหลดซ้ำ
  // ลิสต์เดิม) เริ่มจาก null ตั้งใจ — โหลดครั้งแรกสุดตอนเปิดแอพไม่ควรมีเสียง เพราะเป็นแจ้งเตือนเก่าที่มี
  // อยู่ก่อนแล้ว ไม่ใช่ของใหม่ที่เพิ่งเกิดขึ้น
  Set<String>? _knownIds;

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

      final currentIds = _items.map((n) => n.id).toSet();
      if (_knownIds != null && currentIds.any((id) => !_knownIds!.contains(id))) {
        SoundService.instance.playNotification();
      }
      _knownIds = currentIds;
    } catch (e) {
      // โหลดแจ้งเตือนไม่ได้ไม่ควรทำให้หน้า Notification พัง — ปล่อยเป็นลิสต์ว่างไปก่อน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---- ฉลองหลักฐานภารกิจที่ผ่านการตรวจ (ระบบตรวจสอบภารกิจ) ----
  // แจ้งเตือน quest_approved / bingo (Eco Bingo ครบแถว) ที่มีแต้มและยังไม่เคยฉลอง -> main_shell.dart เล่นเอฟเฟค
  // รางวัลบินเข้าป้ายให้ครั้งเดียว
  // จำ id ที่ฉลองแล้วใน SharedPreferences (ไม่ใช้ isRead เพราะผู้ใช้อาจไม่เคยเปิดหน้า Notification เลย) — เก็บแค่
  // 100 อันล่าสุดพอ แจ้งเตือนจาก backend ส่งมาแค่ 50 ใบอยู่แล้ว
  static const _celebratedKey = 'celebrated_approval_ids';

  // คืนผลรวมแต้ม/XP ของที่ผ่านแล้วยังไม่ได้ฉลอง (null = ไม่มี) แล้วจำว่าฉลองแล้วทันที กันเล่นซ้ำ
  // count = จำนวนหลักฐานที่ผ่าน / bingo = มีแจ้งเตือน Eco Bingo รวมอยู่ด้วยไหม (เปลี่ยนหัวป้าย)
  Future<({int points, int xp, int count, bool bingo})?> takeUncelebratedApprovals() async {
    final approvals = _items
        .where((n) => (n.type == 'quest_approved' || n.type == 'bingo') && n.rewardPoints > 0)
        .toList();
    if (approvals.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final celebrated = prefs.getStringList(_celebratedKey) ?? [];
    final fresh = approvals.where((n) => !celebrated.contains(n.id)).toList();
    if (fresh.isEmpty) return null;

    final updated = [...celebrated, ...fresh.map((n) => n.id)];
    await prefs.setStringList(
      _celebratedKey,
      updated.length > 100 ? updated.sublist(updated.length - 100) : updated,
    );
    return (
      points: fresh.fold<int>(0, (sum, n) => sum + n.rewardPoints),
      xp: fresh.fold<int>(0, (sum, n) => sum + n.rewardXp),
      count: fresh.where((n) => n.type == 'quest_approved').length,
      bingo: fresh.any((n) => n.type == 'bingo'),
    );
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
            rewardPoints: n.rewardPoints,
            rewardXp: n.rewardXp,
          ),
      ];
      notifyListeners();
    } catch (e) {
      // มาร์กอ่านไม่สำเร็จก็แค่ปล่อยจุดแดงค้างไว้ ไม่ต้องรบกวนผู้ใช้ด้วย error
    }
  }
}
