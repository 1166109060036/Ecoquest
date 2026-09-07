import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';

// จัดการ state การ login ของทั้งแอพ ให้ทุกหน้าดึงสถานะ user ปัจจุบันได้
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  ProfileData? _profile;
  bool _isLoading = false;
  bool _isProfileLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  // ข้อมูล level/xp/rank/สถิติ จาก GET /auth/me — null = ยังโหลดไม่เสร็จ (หรือโหลดไม่ได้)
  ProfileData? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _isProfileLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  Future<void> checkSession() async {
    _user = await _authService.getCurrentSession();
    notifyListeners();

    // มี session ค้างอยู่ -> ดึงค่าล่าสุดจาก backend ต่อเลย (ถ้าเน็ตล่มก็ยังใช้ค่าที่ cache ไว้ได้)
    if (_user != null) {
      await refreshProfile();
    }
  }

  // ดึง level/xp/points/rank/สถิติ ของจริงมาเก็บไว้ให้หน้า Profile/Home ใช้
  // ตั้งใจไม่ throw ต่อ เพราะถ้าเน็ตหลุดก็ไม่ควรทำให้เปิดแอพไม่ได้ — แค่โชว์ค่าที่ cache ไว้แทน
  Future<void> refreshProfile() async {
    _isProfileLoading = true;
    notifyListeners();

    try {
      _profile = await _authService.fetchProfile();
      _user = _profile!.user;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isProfileLoading = false;
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
    _profile = null;
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
      // login/register/guest สำเร็จแล้วดึงค่าเกม (level/xp/rank/สถิติ) ตามมาทันที
      // เพราะ endpoint พวกนั้นส่งกลับมาแค่ข้อมูลบัญชี ไม่มีค่าระบบเกมมาด้วย
      await refreshProfile();
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
