import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
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
      throw Exception(data['message'] ?? 'สมัครสมาชิกไม่สำเร็จ');
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
      throw Exception(data['message'] ?? 'เข้าสู่ระบบไม่สำเร็จ');
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
      throw Exception(data['message'] ?? 'เข้าสู่ระบบแบบ guest ไม่สำเร็จ');
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
      throw Exception(data['message'] ?? 'รหัสผ่านไม่ถูกต้อง');
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
      throw Exception(data['message'] ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
    }
  }

  // ขอ OTP ไปที่อีเมล (ขั้นตอนแรกของ "ลืมรหัสผ่าน")
  Future<void> requestPasswordResetOtp({required String email}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'ส่ง OTP ไม่สำเร็จ');
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
      throw Exception(data['message'] ?? 'OTP ไม่ถูกต้องหรือหมดอายุ');
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
      throw Exception(data['message'] ?? 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ');
    }
  }
}
