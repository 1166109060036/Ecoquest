import 'dart:convert';
import 'api_http.dart' as http;
import '../models/impact_model.dart';
import '../models/submission_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// ฟีดกิจกรรมชุมชน + ผลกระทบรวมของเมือง (backend/routes/feed.js, backend/routes/impact.js)
// รูปแบบ HTTP เดียวกับ friend_service.dart
class FeedService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // before = submittedAt ของโพสต์สุดท้ายที่มีแล้ว (โหลดหน้าถัดไป) / null = หน้าแรก
  Future<({List<SubmissionModel> items, bool hasMore})> fetchFeed({DateTime? before}) async {
    final query = before != null ? '?before=${Uri.encodeQueryComponent(before.toUtc().toIso8601String())}' : '';
    final response = await http.get(Uri.parse('${AppConstants.baseUrl}/feed$query'), headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load the community feed');
    }
    final items = ((data['items'] ?? []) as List)
        .map((s) => SubmissionModel.fromJson(s as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: data['hasMore'] == true);
  }

  // toggle — คืนจำนวน cheer ล่าสุด + ตัวเองกดอยู่ไหม
  Future<({int cheers, bool cheeredByMe})> toggleCheer(String postId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/feed/$postId/cheer'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to cheer');
    }
    return (cheers: (data['cheers'] ?? 0) as int, cheeredByMe: data['cheeredByMe'] == true);
  }

  // ถอนโพสต์ออกจากฟีด + ลบรูป (แอดมิน หรือเจ้าของโพสต์) — แต้มที่ได้ไปแล้วไม่ถูกยึดคืน
  Future<void> removePost(String postId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/feed/$postId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to remove this post');
    }
  }

  // รายงานโพสต์ — reason: not_done / personal_info / inappropriate / other (submission_model.dart reportReasonLabels)
  Future<void> reportPost(String postId, String reason) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/feed/$postId/report'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to report this post');
    }
  }

  Future<ImpactSummary> fetchImpact() async {
    final response = await http.get(Uri.parse('${AppConstants.baseUrl}/impact/summary'), headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Failed to load the city's impact");
    }
    return ImpactSummary.fromJson(data as Map<String, dynamic>);
  }
}
