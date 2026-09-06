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

  Future<bool> verifyCurrentPassword(String password) async {
    return _runAction(() => _authService.verifyCurrentPassword(password));
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    return _runAction(() => _authService.changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
        ));
  }

  Future<bool> requestPasswordResetOtp(String email) async {
    return _runAction(() => _authService.requestPasswordResetOtp(email: email));
  }

  Future<bool> resetPassword(String resetToken, String newPassword) async {
    return _runAction(() => _authService.resetPassword(
          resetToken: resetToken,
          newPassword: newPassword,
        ));
  }

  // ต่างจาก _runAction เพราะต้องคืน resetToken กลับไปให้หน้า UI ใช้ต่อ ไม่ใช่แค่สำเร็จ/ไม่สำเร็จ
  Future<String?> verifyPasswordResetOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resetToken = await _authService.verifyPasswordResetOtp(email: email, otp: otp);
      _isLoading = false;
      notifyListeners();
      return resetToken;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
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

  // เหมือน _runAuthAction แต่ใช้กับ action ที่ไม่ได้คืน UserModel กลับมา
  // (เปลี่ยนรหัสผ่าน / ขอ OTP / ตั้งรหัสผ่านใหม่ — ไม่กระทบ _user ที่ login อยู่)
  Future<bool> _runAction(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
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
