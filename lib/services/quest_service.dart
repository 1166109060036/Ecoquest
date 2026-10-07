import 'dart:convert';
import 'dart:typed_data';
import 'api_http.dart' as http;
import '../models/quest_card_model.dart';
import '../models/quest_history_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ฝั่ง quest ทั้งหมด (ลิสต์ quest / ทำ quest สำเร็จ)
// ทั้ง 2 endpoint ต้องแนบ token เพราะ backend ต้องรู้ว่าเป็น quest ของ user คนไหน
// (โดยเฉพาะ timesToday ที่คิดจากประวัติของ user คนนั้น)
class QuestService {
  final StorageService _storage = StorageService();

  // combo = สรุป Daily Variety Combo วันนี้ (backend/utils/combo.js) — null ถ้า backend รุ่นเก่ายังไม่ส่งมา
  Future<({List<QuestCardModel> quests, ComboSummary? combo})> fetchQuests() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/quests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load quests');
    }

    final comboJson = data['combo'] as Map<String, dynamic>?;
    return (
      quests: (data['quests'] as List)
          .map((q) => QuestCardModel.fromJson(q as Map<String, dynamic>))
          .toList(),
      combo: comboJson != null ? ComboSummary.fromJson(comboJson) : null,
    );
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

  // เควสที่ requiresProof ต้องส่งรูปหลักฐานมาด้วย (base64 ใน JSON แบบรูปในตู้เย็น) -> backend ตอบ 201 status: 'pending'
  // (รอตรวจ ยังไม่ได้แต้ม) / Check Food ไม่ต้องมีรูป -> 200 status: 'completed' ได้แต้มทันทีเหมือนเดิม
  Future<QuestReward> completeQuest(
    String questId, {
    Uint8List? photoBytes,
    String? photoContentType,
    Map<String, dynamic>? proofDetails, // คำตอบฟอร์มของเควส (models/proof_form.dart)
  }) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/quests/$questId/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (photoBytes != null) 'photoBase64': base64Encode(photoBytes),
        if (photoContentType != null) 'photoContentType': photoContentType,
        'proofDetails': ?proofDetails,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to complete quest');
    }

    return QuestReward.fromResponse(data);
  }

  // กด Start เควส — แค่บันทึกว่ากำลังทำอยู่ ยังไม่ได้คะแนน ต้องไปกด Complete ที่หน้า Progress อีกที
  Future<void> startQuest(String questId) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/quests/$questId/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to start quest');
    }
  }

  // ยกเลิกเควสที่กด Start ไว้ (เอาออกจากหน้า Progress โดยไม่ได้คะแนน)
  Future<void> cancelQuest(String questId) async {
    final token = await _storage.getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/quests/$questId/start'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to cancel quest');
    }
  }

  // เควสที่กด Start ไว้แล้วแต่ยังไม่กด Complete — โชว์ในหน้า Progress
  Future<List<QuestCardModel>> fetchProgress() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/quests/progress'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load quest progress');
    }

    return (data['progress'] as List)
        .map((q) => QuestCardModel.fromJson(q as Map<String, dynamic>))
        .toList();
  }
}
