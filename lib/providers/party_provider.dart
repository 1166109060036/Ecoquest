import 'package:flutter/material.dart';
import '../models/party_model.dart';
import '../services/party_service.dart';

// ถือปาร์ตี้ปัจจุบันของผู้เล่น (อยู่ได้ทีละปาร์ตี้เดียวตามดีไซน์)
class PartyProvider extends ChangeNotifier {
  final PartyService _service = PartyService();

  PartyModel? _party;
  bool _isLoading = false;
  bool _isBusy = false; // ระหว่างกด join/leave
  String? _errorMessage;

  PartyModel? get party => _party;
  bool get hasParty => _party != null;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> loadParty() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _party = await _service.fetchParty();
    } catch (e) {
      // โหลดไม่ได้ไม่ควรทำให้หน้า Party พัง — โชว์ empty state พร้อมข้อความแทน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> join(String questId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _party = await _service.joinParty(questId);
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

  Future<bool> leave() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.leaveParty();
      _party = null;
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
