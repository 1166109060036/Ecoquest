import 'dart:convert';
import 'api_http.dart' as http;
import '../models/bingo_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// Eco Bingo รายสัปดาห์ (backend/routes/bingo.js) — รูปแบบ HTTP เดียวกับ submission_service.dart
class BingoService {
  final StorageService _storage = StorageService();

  Future<BingoCardModel> fetchCard() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/bingo'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load Eco Bingo');
    }
    return BingoCardModel.fromJson(data as Map<String, dynamic>);
  }
}
