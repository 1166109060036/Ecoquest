import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ดึงประวัติแชท (REST อย่างเดียว) — ส่งข้อความจริงทำผ่าน WebSocket เท่านั้น
// (ดู chat_socket_service.dart) เพราะมีทางเขียนทางเดียวชัดเจน ไม่ต้องกังวลว่าข้อความจะมาจาก 2 ทาง
// แล้ว sync กันไม่ตรง — REST มีไว้ให้ดึงกลับมาดูตอนเปิดแชท/reconnect เท่านั้น
class ChatService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<ChatMessageModel>> fetchWorldHistory({DateTime? before, int limit = 30}) =>
      _fetchHistory('${AppConstants.baseUrl}/chat/world/messages', before: before, limit: limit);

  // ห้องปาร์ตี้ที่ req.userId อยู่ตอนนี้ — backend หา partyId เองจาก membership จริง (ไม่ส่ง partyId
  // ไปจากฝั่งแอพ) ถ้าไม่ได้อยู่ปาร์ตี้ backend ตอบ 400 กลายเป็น Exception ที่นี่
  Future<List<ChatMessageModel>> fetchPartyHistory({DateTime? before, int limit = 30}) =>
      _fetchHistory('${AppConstants.baseUrl}/chat/party/messages', before: before, limit: limit);

  Future<List<ChatMessageModel>> fetchFriendHistory(
    String friendUserId, {
    DateTime? before,
    int limit = 30,
  }) =>
      _fetchHistory(
        '${AppConstants.baseUrl}/chat/friend/$friendUserId/messages',
        before: before,
        limit: limit,
      );

  Future<List<ChatMessageModel>> _fetchHistory(String url, {DateTime? before, int limit = 30}) async {
    final query = {
      if (before != null) 'before': before.toUtc().toIso8601String(),
      'limit': '$limit',
    };
    final response = await http.get(
      Uri.parse(url).replace(queryParameters: query),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load chat history');
    }

    return ((data['messages'] ?? []) as List)
        .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }
}
