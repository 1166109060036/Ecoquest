import 'dart:convert';
import 'api_http.dart' as http;
import '../models/submission_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ของระบบตรวจสอบภารกิจ (คิวตรวจ/โหวต/หลักฐานของฉัน) — รูปแบบ HTTP เดียวกับ friend_service.dart
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

  Future<ReviewQueue> fetchQueue() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/reviews/queue'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load the review queue');
    }
    return ReviewQueue(
      submissions: _parseList(data['submissions']),
      pendingCount: data['pendingCount'] ?? 0,
      isAdmin: data['isAdmin'] ?? false,
      canReview: data['canReview'] ?? true,
      escalatedCount: data['escalatedCount'] ?? 0,
      rewardPoints: data['reviewReward']?['points'] ?? 0,
      rewardXp: data['reviewReward']?['xp'] ?? 0,
      rewardsToday: data['reviewRewardsToday'] ?? 0,
      rewardsCap: data['reviewRewardsCap'] ?? 0,
    );
  }

  // คืนสถานะหลังโหวต (pending / approved / rejected) + รางวัลคนตรวจที่ได้จากโหวตนี้
  Future<VoteResult> vote(String submissionId, {required bool approve}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/reviews/$submissionId/vote'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to send your review');
    }
    return VoteResult(
      status: data['status'] ?? 'pending',
      rewardPoints: data['reward']?['points'] ?? 0,
      rewardXp: data['reward']?['xp'] ?? 0,
      rewardsToday: data['reviewRewardsToday'] ?? 0,
      rewardsCap: data['reviewRewardsCap'] ?? 0,
    );
  }
}
