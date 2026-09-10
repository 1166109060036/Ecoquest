import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/party_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ของระบบปาร์ตี้ (อีเวนต์กลุ่ม)
class PartyService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // null = ยังไม่ได้เข้าร่วมปาร์ตี้ไหนเลย
  Future<PartyModel?> fetchParty() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/party'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load your party');
    }
    if (data['party'] == null) return null;

    return PartyModel.fromJson(data['party'] as Map<String, dynamic>);
  }

  Future<PartyModel> joinParty(String questId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/party/join/$questId'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to join this event');
    }

    return PartyModel.fromJson(data['party'] as Map<String, dynamic>);
  }

  Future<void> leaveParty() async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/party/leave'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to leave the party');
    }
  }
}
