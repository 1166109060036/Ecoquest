import 'package:flutter/material.dart';
import '../models/upgrade_model.dart';
import '../services/upgrade_service.dart';

// ถือรายการ upgrade ไว้ให้การ์ด "Upgrade your Ability" ในหน้า Profile ใช้
class UpgradeProvider extends ChangeNotifier {
  final UpgradeService _service = UpgradeService();

  List<UpgradeModel> _items = [];
  bool _isLoading = false;
  bool _isBusy = false; // ระหว่างกดซื้อ
  String? _errorMessage;

  List<UpgradeModel> get items => _items;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> loadUpgrades() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _service.fetchUpgrades();
    } catch (e) {
      // โหลดไม่ได้ไม่ควรทำให้หน้า Profile พัง — ปล่อยเป็นลิสต์ว่างไปก่อน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ซื้อ upgrade 1 ระดับ — สำเร็จแล้วอัปเดต level ในลิสต์ทันทีไม่ต้องรอโหลดใหม่
  // ⚠️ ไม่แตะยอดแต้มของผู้ใช้ตรงนี้ เพราะยอดแต้มอยู่ใน AuthProvider คนละตัว —
  // ผู้เรียกต้องเรียก AuthProvider.refreshProfile() ต่อเอง (ดู profile_page.dart)
  // และถ้าซื้อ Quest Unlock ต้องเรียก QuestProvider.loadQuests() ด้วย เพราะจำนวนเควสที่เห็นเปลี่ยน
  Future<bool> buy(String upgradeType) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final (updated, _) = await _service.buyUpgrade(upgradeType);
      _items = [
        for (final item in _items)
          if (item.upgradeType == upgradeType) updated else item,
      ];
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
