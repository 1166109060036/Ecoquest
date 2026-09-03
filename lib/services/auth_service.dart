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
}
