import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// จัดการ state การ login ของทั้งแอพ ให้ทุกหน้าดึงสถานะ user ปัจจุบันได้
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  Future<void> checkSession() async {
    _user = await _authService.getCurrentSession();
    notifyListeners();
  }

  Future<bool> register(String email, String password, {String? displayName}) async {
    return _runAuthAction(() => _authService.register(
          email: email,
          password: password,
          displayName: displayName,
        ));
  }

  Future<bool> login(String email, String password) async {
    return _runAuthAction(() => _authService.login(email: email, password: password));
  }

  Future<bool> loginAsGuest() async {
    return _runAuthAction(() => _authService.loginAsGuest());
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(Future<UserModel> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await action();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
