import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';

// ถือ 3 อย่าง: ลิสต์เพื่อน, ผลค้นหา, คำขอที่รอตอบ (เข้า/ออก) — โครงเดียวกับ PartyProvider
class FriendProvider extends ChangeNotifier {
  final FriendService _service = FriendService();

  List<FriendModel> _friends = [];
  bool _isLoadingFriends = false;
  String? _errorMessage;

  List<FriendSearchResultModel> _searchResults = [];
  bool _isSearching = false;
  String? _searchErrorMessage;

  List<FriendRequestModel> _incomingRequests = [];
  List<FriendRequestModel> _outgoingRequests = [];
  bool _isLoadingRequests = false;

  bool _isBusy = false; // ระหว่างกด send/accept/reject/cancel/remove

  List<FriendModel> get friends => _friends;
  bool get isLoadingFriends => _isLoadingFriends;
  String? get errorMessage => _errorMessage;

  List<FriendSearchResultModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchErrorMessage => _searchErrorMessage;

  List<FriendRequestModel> get incomingRequests => _incomingRequests;
  List<FriendRequestModel> get outgoingRequests => _outgoingRequests;
  bool get isLoadingRequests => _isLoadingRequests;

  bool get isBusy => _isBusy;

  Future<void> loadFriends() async {
    _isLoadingFriends = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _friends = await _service.fetchFriends();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoadingFriends = false;
    notifyListeners();
  }

  Future<void> loadRequests() async {
    _isLoadingRequests = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.fetchRequests(incoming: true),
        _service.fetchRequests(incoming: false),
      ]);
      _incomingRequests = results[0];
      _outgoingRequests = results[1];
    } catch (e) {
      // คำขอโหลดไม่ได้ไม่ควรทำให้แท็บ Friend พัง — เหลือลิสต์เดิม (หรือว่างถ้าเพิ่งเปิดครั้งแรก) ไปเงียบๆ
    }

    _isLoadingRequests = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _searchErrorMessage = null;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchErrorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _service.searchUsers(query);
    } catch (e) {
      _searchErrorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isSearching = false;
    notifyListeners();
  }

  Future<bool> sendRequest(String userId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.sendRequest(userId);
      // อาจเป็นคำขอใหม่ (pending) หรือ auto-accept ทันที (อีกฝ่ายเคยส่งมาก่อน) — โหลดทั้งคู่ใหม่
      // ให้ชัวร์ว่า UI (ปุ่ม Add -> Pending/Friends) อัปเดตตรงกับสถานะจริงบน backend เสมอ
      await Future.wait([loadRequests(), loadFriends()]);
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

  Future<bool> acceptRequest(String requestId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.acceptRequest(requestId);
      await Future.wait([loadRequests(), loadFriends()]);
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

  Future<bool> rejectRequest(String requestId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.rejectRequest(requestId);
      _incomingRequests = _incomingRequests.where((r) => r.id != requestId).toList();
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

  Future<bool> cancelRequest(String requestId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.cancelRequest(requestId);
      _outgoingRequests = _outgoingRequests.where((r) => r.id != requestId).toList();
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

  Future<bool> removeFriend(String friendUserId) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.removeFriend(friendUserId);
      _friends = _friends.where((f) => f.id != friendUserId).toList();
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
