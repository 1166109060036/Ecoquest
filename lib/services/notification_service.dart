import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// ดึงแจ้งเตือนของผู้เล่น (สร้างแจ้งเตือนของใกล้หมดอายุให้อัตโนมัติฝั่ง backend ตอนดึง)
class NotificationService {
  final StorageService _storage = StorageService();

  Future<List<NotificationModel>> fetchNotifications() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load notifications');
    }

    return (data['notifications'] as List)
        .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAllRead() async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/notifications/read'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to mark notifications as read');
    }
  }
}
