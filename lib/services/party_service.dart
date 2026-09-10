import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/party_model.dart';
import '../models/quest_card_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ของระบบห้องปาร์ตี้ (สร้างห้องจาก party quest / เข้าร่วม / หัวหน้ากดจบอีเวนต์)
class PartyService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // null = ยังไม่ได้อยู่ห้องไหนเลย
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

  // ลิสต์ห้องที่ยังเปิดรับสมาชิกอยู่ ให้เลือกเข้าร่วม
  Future<List<PartyRoomModel>> fetchRooms() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/party/rooms'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load party rooms');
    }

    return ((data['rooms'] ?? []) as List)
        .map((r) => PartyRoomModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // สร้างห้องใหม่จาก party quest ที่มีอยู่แล้ว — ผู้สร้างเป็นหัวหน้าห้องทันที
  Future<PartyModel> createParty({
    required String questId,
    required String name,
    required DateTime eventDate,
    String? location,
    int? capacity,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/party'),
      headers: await _headers(),
      body: jsonEncode({
        'questId': questId,
        'name': name,
        'eventDate': eventDate.toUtc().toIso8601String(),
        'location': location,
        'capacity': capacity,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to create the party');
    }

    return PartyModel.fromJson(data['party'] as Map<String, dynamic>);
  }

  Future<PartyModel> joinParty(String partyId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/party/join/$partyId'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to join this party');
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

  // หัวหน้าห้องกดจบอีเวนต์ — ทุกคนในห้องได้คะแนนพร้อมกัน
  Future<PartyCompleteReward> completeParty() async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/party/complete'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to complete this event');
    }

    return PartyCompleteReward(
      reward: QuestReward.fromResponse(data),
      awardedCount: data['awardedCount'] ?? 0,
      party: PartyModel.fromJson(data['party'] as Map<String, dynamic>),
    );
  }
}
