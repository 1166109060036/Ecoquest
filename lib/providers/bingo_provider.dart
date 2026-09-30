import 'package:flutter/material.dart';
import '../models/bingo_model.dart';
import '../services/bingo_service.dart';

// การ์ด Eco Bingo สัปดาห์นี้ — แถบบนลิสต์เควส (widgets/quest_boost_bar.dart) และหน้า Bingo ใช้ร่วมกัน
// โหลดตอนเข้าแอพ (main_shell.dart), ตอนเควสผ่านการตรวจ, ตอนทำ Check Food สำเร็จ และตอนเปิดหน้า Bingo
class BingoProvider extends ChangeNotifier {
  final BingoService _service = BingoService();

  BingoCardModel? _card;
  bool _isLoading = false;
  String? _errorMessage;

  BingoCardModel? get card => _card;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadBingo() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _card = await _service.fetchCard();
    } catch (e) {
      // โหลดไม่ได้ไม่ควรทำให้หน้า Explore พัง — แถบแค่ซ่อนตัวไป
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }
}
