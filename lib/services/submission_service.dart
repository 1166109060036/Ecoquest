import 'dart:convert';
import 'api_http.dart' as http;
import '../models/submission_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API หลักฐานภารกิจ (หลักฐานของฉัน / โพสต์ที่ถูกรายงานของแอดมิน) — รูปแบบ HTTP เดียวกับ friend_service.dart
class SubmissionService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  List<SubmissionModel> _parseList(dynamic list) =>
      ((list ?? []) as List).map((s) => SubmissionModel.fromJson(s as Map<String, dynamic>)).toList();

  // หลักฐานที่ตัวเองส่ง (รวมรูปกลุ่มของห้องที่ตัวเองอยู่) — status: null = ทุกสถานะ
  Future<List<SubmissionModel>> fetchMine({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/submissions/mine$query'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load your submissions');
    }
    return _parseList(data['submissions']);
  }

  // โพสต์ที่ถูกรายงานรอแอดมินดู — ผู้เล่นทั่วไปได้ลิสต์ว่าง (isAdmin: false)
  Future<ReportQueue> fetchQueue() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/reviews/queue'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load reported posts');
    }
    return ReportQueue(
      submissions: _parseList(data['submissions']),
      pendingCount: data['pendingCount'] ?? 0,
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  // แอดมินตัดสินโพสต์ที่ถูกรายงาน — action: keep / remove (ถอนรูป แต้มอยู่) / revoke (ถอนรูป + ยึดแต้มคืน)
  Future<void> resolveReport(String submissionId, String action) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/reviews/$submissionId/resolve'),
      headers: await _headers(),
      body: jsonEncode({'action': action}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to resolve this report');
    }
  }
}
