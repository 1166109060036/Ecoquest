import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/achievement_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// ดึงเหรียญ Achievement ของผู้เล่น (ทั้งที่ปลดล็อกแล้วและยังไม่ปลดล็อก + ความคืบหน้า)
class AchievementService {
  final StorageService _storage = StorageService();

  Future<List<AchievementMedalModel>> fetchAchievements() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/achievements'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load achievements');
    }

    return (data['achievements'] as List)
        .map((a) => AchievementMedalModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}
