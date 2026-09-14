import 'package:flutter/material.dart';
import '../services/admin_service.dart';

// thin provider ห่อ AdminService — เก็บแค่ isBusy/errorMessage ให้ AdminPage โชว์สถานะ
// ไม่เก็บ state ของระบบอื่นซ้ำ (points/items/quests ฯลฯ ยังอยู่ที่ provider เดิมของระบบนั้นเหมือนเดิม)
// AdminPage เป็นแค่ "รีโมตคอนโทรล" — หลัง action สำเร็จ หน้าเพจเองเป็นคนเรียก provider อื่น refresh ต่อ
class AdminProvider extends ChangeNotifier {
  final AdminService _service = AdminService();
  AdminService get service => _service;

  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  // เรียก action ที่มีค่าคืนกลับ (debugMe/listParties/listSeasons) แบบมี busy/error state ให้อัตโนมัติ
  // คืนผลลัพธ์ของ action ถ้าสำเร็จ, null ถ้าพัง (เช็ค errorMessage ต่อได้)
  Future<T?> run<T>(Future<T> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await action();
      _isBusy = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isBusy = false;
      notifyListeners();
      return null;
    }
  }

  // เหมือน run() แต่ใช้กับ action ที่คืน Future<void> (ส่วนใหญ่ของ AdminService) — คืน bool
  // แทน T? เพราะ Dart เทียบ void กับ null ตรงๆ ไม่ได้ (use_of_void_result)
  Future<bool> runVoid(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }
}
