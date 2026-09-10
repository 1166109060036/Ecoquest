import 'package:flutter/material.dart';
import '../models/party_model.dart';
import '../models/quest_card_model.dart';
import '../services/party_service.dart';

// ถือ 2 อย่าง: ห้องปัจจุบันของผู้เล่น (อยู่ได้ทีละห้องเดียวตามดีไซน์) + ลิสต์ห้องให้เลือกเข้าร่วม
class PartyProvider extends ChangeNotifier {
  final PartyService _service = PartyService();

  PartyModel? _party;
  bool _isLoading = false;
  bool _isBusy = false; // ระหว่างกด create/join/leave/complete
  String? _errorMessage;

  List<PartyRoomModel> _rooms = [];
  bool _isLoadingRooms = false;
  String? _roomsErrorMessage;

  PartyModel? get party => _party;
  bool get hasParty => _party != null;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  List<PartyRoomModel> get rooms => _rooms;
  bool get isLoadingRooms => _isLoadingRooms;
  String? get roomsErrorMessage => _roomsErrorMessage;

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

  Future<void> loadRooms() async {
    _isLoadingRooms = true;
    _roomsErrorMessage = null;
    notifyListeners();

    try {
      _rooms = await _service.fetchRooms();
    } catch (e) {
      _roomsErrorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoadingRooms = false;
    notifyListeners();
  }

  Future<bool> create({
    required String questId,
    required String name,
    required DateTime eventDate,
    String? location,
    int? capacity,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _party = await _service.createParty(
        questId: questId,
        name: name,
        eventDate: eventDate,
        location: location,
        capacity: capacity,
      );
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

  Future<bool> join(String partyId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _party = await _service.joinParty(partyId);
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

  // หัวหน้าห้องกดจบอีเวนต์ — คืน reward ของหัวหน้าเอง (null ถ้าล้มเหลว) ให้หน้า Party
  // เอาไปเข้า handleQuestCompleted แบบเดียวกับ quest ทั่วไป
  Future<QuestReward?> complete() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.completeParty();
      _party = result.party;
      _isBusy = false;
      notifyListeners();
      return result.reward;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isBusy = false;
      notifyListeners();
      return null;
    }
  }
}
