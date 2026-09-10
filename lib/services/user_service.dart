import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/public_profile_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ดูโปรไฟล์สาธารณะของผู้เล่นคนอื่น
class UserService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<PublicProfileModel> fetchPublicProfile(String userId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/users/$userId'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load this player\'s profile');
    }

    return PublicProfileModel.fromJson(data as Map<String, dynamic>);
  }
}
