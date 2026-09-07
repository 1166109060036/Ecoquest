import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/profile_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// รวม logic การเรียก API ฝั่ง auth ทั้งหมด (register / login / guest / logout)
class AuthService {
  final StorageService _storage = StorageService();

  Future<UserModel> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Sign up failed');
    }

    final user = UserModel.fromJson(data['user']);
    await _storage.saveSession(data['token'], user);
    return user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Sign in failed');
    }

    final user = UserModel.fromJson(data['user']);
    await _storage.saveSession(data['token'], user);
    return user;
  }

  Future<UserModel> loginAsGuest() async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/guest'),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Guest sign in failed');
    }

    final user = UserModel.fromJson(data['user']);
    await _storage.saveSession(data['token'], user);
    return user;
  }

  // เช็คว่ามี session ค้างอยู่ไหม (ใช้ตอนเปิดแอพ / splash page)
  Future<UserModel?> getCurrentSession() async {
    final token = await _storage.getToken();
    if (token == null) return null;
    return _storage.getUser();
  }

  // ดึงข้อมูล user ปัจจุบัน + level/xp/rank + สถิติ จาก backend (ของจริง ไม่ใช่ mock)
  // อัปเดต session ที่ cache ไว้ด้วย เพื่อให้เปิดแอพครั้งหน้าเห็นค่าล่าสุดทันทีก่อน fetch เสร็จ
  Future<ProfileData> fetchProfile() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load your profile');
    }

    final profile = ProfileData.fromJson(data);
    if (token != null) {
      await _storage.saveSession(token, profile.user);
    }
    return profile;
  }

  Future<void> logout() async {
    await _storage.clearSession();
  }

  // เช็ครหัสผ่านปัจจุบันว่าถูกไหม — ใช้ในขั้นตอนแรกของหน้า Change Password
  Future<void> verifyCurrentPassword(String password) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/verify-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Incorrect password');
    }
  }

  // เปลี่ยนรหัสผ่านตอน login อยู่แล้ว (ต้องแนบ token ไปด้วย)
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to change password');
    }
  }

  // ขอ OTP ไปที่อีเมล (ขั้นตอนแรกของ "Forgot Password")
  Future<void> requestPasswordResetOtp({required String email}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }
  }

  // ยืนยัน OTP -> ได้ resetToken อายุสั้นไว้ใช้ตั้งรหัสผ่านใหม่
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/verify-reset-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Invalid or expired OTP');
    }
    return data['resetToken'];
  }

  // ตั้งรหัสผ่านใหม่ด้วย resetToken ที่ได้จาก verifyPasswordResetOtp
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'resetToken': resetToken, 'newPassword': newPassword}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to reset password');
    }
  }
}
