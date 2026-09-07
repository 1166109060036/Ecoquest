import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quest_card_model.dart';
import '../models/quest_history_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ฝั่ง quest ทั้งหมด (ลิสต์ quest / ทำ quest สำเร็จ)
// ทั้ง 2 endpoint ต้องแนบ token เพราะ backend ต้องรู้ว่าเป็น quest ของ user คนไหน
// (โดยเฉพาะ completedToday ที่คิดจากประวัติของ user คนนั้น)
class QuestService {
  final StorageService _storage = StorageService();

  Future<List<QuestCardModel>> fetchQuests() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/quests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load quests');
    }

    return (data['quests'] as List)
        .map((q) => QuestCardModel.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  // ประวัติ quest ที่ทำสำเร็จ (ล่าสุดขึ้นก่อน) — ใช้โชว์ในหน้า Profile
  Future<List<QuestHistoryEntry>> fetchHistory({int limit = 20}) async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/quests/history?limit=$limit'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load quest history');
    }

    return (data['history'] as List)
        .map((h) => QuestHistoryEntry.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  Future<QuestReward> completeQuest(String questId) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/quests/$questId/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to complete quest');
    }

    return QuestReward.fromJson(data['earned'] ?? {});
  }
}
