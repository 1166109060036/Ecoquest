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

  Future<ImpactSummary> fetchImpact() async {
    final response = await http.get(Uri.parse('${AppConstants.baseUrl}/impact/summary'), headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? "Failed to load the city's impact");
    }
    return ImpactSummary.fromJson(data as Map<String, dynamic>);
  }
}
