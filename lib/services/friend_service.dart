import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/friend_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ของระบบเพื่อน (ค้นหา/ส่ง-รับ-ปฏิเสธ-ยกเลิกคำขอ/ลิสต์เพื่อน/ลบเพื่อน)
// รูปแบบ HTTP เดียวกับ party_service.dart เป๊ะๆ
class FriendService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<FriendSearchResultModel>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/friends/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to search players');
    }

    return ((data['results'] ?? []) as List)
        .map((r) => FriendSearchResultModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendRequest(String recipientId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/friends/requests'),
      headers: await _headers(),
      body: jsonEncode({'recipientId': recipientId}),
    );

    final data = jsonDecode(response.body);
    // ส่งสำเร็จ (201 คำขอใหม่) หรือ auto-accept ทันที (200 อีกฝ่ายเคยส่งมาก่อนแล้ว) ทั้งคู่ถือว่าสำเร็จ
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to send friend request');
    }
  }

  Future<List<FriendRequestModel>> fetchRequests({required bool incoming}) async {
    final direction = incoming ? 'incoming' : 'outgoing';
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/friends/requests?direction=$direction'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load friend requests');
    }

    return ((data['requests'] ?? []) as List)
        .map((r) => FriendRequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptRequest(String requestId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/friends/requests/$requestId/accept'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to accept this request');
    }
  }

  Future<void> rejectRequest(String requestId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/friends/requests/$requestId/reject'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to reject this request');
    }
  }

  Future<void> cancelRequest(String requestId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/friends/requests/$requestId/cancel'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to cancel this request');
    }
  }

  Future<List<FriendModel>> fetchFriends() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/friends'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load your friends');
    }

    return ((data['friends'] ?? []) as List)
        .map((f) => FriendModel.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeFriend(String friendUserId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/friends/$friendUserId'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to remove this friend');
    }
  }
}
