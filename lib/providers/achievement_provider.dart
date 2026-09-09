import 'package:flutter/material.dart';
import '../models/achievement_model.dart';
import '../services/achievement_service.dart';

// ถือรายการเหรียญไว้ให้หน้า Inventory ใช้
// โหลดครั้งเดียวตอนเข้าแอพ แล้วโหลดใหม่ทุกครั้งที่ทำ quest สำเร็จ (ความคืบหน้าอาจขยับ)
class AchievementProvider extends ChangeNotifier {
  final AchievementService _service = AchievementService();

  List<AchievementMedalModel> _achievements = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AchievementMedalModel> get achievements => _achievements;
  List<AchievementMedalModel> get unlocked =>
      _achievements.where((a) => a.unlocked).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAchievements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _achievements = await _service.fetchAchievements();
    } catch (e) {
      // โหลดเหรียญไม่ได้ไม่ควรทำให้หน้า Inventory พัง — ปล่อยเป็นลิสต์ว่างไปก่อน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }
}
