import 'dart:convert';
import 'api_http.dart' as http;
import '../models/org_event_model.dart';
import '../models/quest_card_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// บัญชีองค์กร + อีเวนต์องค์กร (backend/routes/org.js) — รูปแบบ HTTP เดียวกับ feed_service.dart
class OrgService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Uri _url(String path) => Uri.parse('${AppConstants.baseUrl}/org$path');

  Map<String, dynamic> _decode(dynamic response, String fallback, {List<int> ok = const [200, 201]}) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(fallback);
    }
    if (!ok.contains(response.statusCode)) {
      throw Exception(data['message'] ?? fallback);
    }
    return data;
  }

  List<OrgEventModel> _events(Map<String, dynamic> data) =>
      ((data['events'] ?? []) as List).map((e) => OrgEventModel.fromJson(e as Map<String, dynamic>)).toList();

  // ---- บัญชีองค์กร ----
  Future<({OrgProfile org, bool canApply, String email})> fetchMyOrg() async {
    final data = _decode(await http.get(_url('/me'), headers: await _headers()), 'Failed to load your organization');
    return (
      org: OrgProfile.fromJson(data['organization'] as Map<String, dynamic>?),
      canApply: data['canApply'] == true,
      email: (data['email'] ?? '') as String,
    );
  }

  Future<OrgProfile> apply({
    required String name,
    required String orgType,
    required String description,
    required String contactEmail,
  }) async {
    final data = _decode(
      await http.post(
        _url('/apply'),
        headers: await _headers(),
        body: jsonEncode({'name': name, 'orgType': orgType, 'description': description, 'contactEmail': contactEmail}),
      ),
      'Failed to send your request',
    );
    return OrgProfile.fromJson(data['organization'] as Map<String, dynamic>?);
  }

  // องค์กรที่อนุมัติแล้วแก้ข้อมูลตัวเอง (PUT /org/me)
  Future<OrgProfile> updateOrg({
    required String name,
    required String orgType,
    required String description,
    required String contactEmail,
  }) async {
    final data = _decode(
      await http.put(
        _url('/me'),
        headers: await _headers(),
        body: jsonEncode({'name': name, 'orgType': orgType, 'description': description, 'contactEmail': contactEmail}),
      ),
      'Failed to save your changes',
    );
    return OrgProfile.fromJson(data['organization'] as Map<String, dynamic>?);
  }

  // ---- อีเวนต์ ----
  Future<List<OrgEventModel>> fetchEvents() async =>
      _events(_decode(await http.get(_url('/events'), headers: await _headers()), 'Failed to load events'));

  Future<List<OrgEventModel>> fetchJoinedEvents() async =>
      _events(_decode(await http.get(_url('/events/joined'), headers: await _headers()), 'Failed to load your events'));

  Future<List<OrgEventModel>> fetchMyEvents() async =>
      _events(_decode(await http.get(_url('/events/mine'), headers: await _headers()), 'Failed to load your events'));

  Future<OrgEventModel> fetchEvent(String id) async {
    final data = _decode(await http.get(_url('/events/$id'), headers: await _headers()), 'Failed to load this event');
    return OrgEventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<OrgEventModel> register(String id) async {
    final data = _decode(await http.post(_url('/events/$id/register'), headers: await _headers()), 'Failed to join');
    return OrgEventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<OrgEventModel> unregister(String id) async {
    final data = _decode(
      await http.delete(_url('/events/$id/register'), headers: await _headers()),
      'Failed to cancel',
    );
    return OrgEventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  // สแกน QR ที่งาน — คืนรางวัลในรูปเดียวกับทำเควสสำเร็จ (เอาเข้า handleQuestCompleted ได้เลย) + อีเวนต์ล่าสุด
  Future<({QuestReward reward, OrgEventModel event})> checkIn(String code) async {
    final data = _decode(
      await http.post(_url('/checkin'), headers: await _headers(), body: jsonEncode({'code': code})),
      'Check-in failed',
    );
    return (
      reward: QuestReward.fromResponse(data),
      event: OrgEventModel.fromJson(data['event'] as Map<String, dynamic>),
    );
  }

  // ---- ฝั่งองค์กร ----
  Future<OrgEventModel> createEvent({
    required String title,
    required String description,
    required String category,
    required String location,
    required DateTime startAt,
    required DateTime endAt,
    required int capacity,
    required int points,
  }) async {
    final data = _decode(
      await http.post(
        _url('/events'),
        headers: await _headers(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          'location': location,
          'startAt': startAt.toUtc().toIso8601String(),
          'endAt': endAt.toUtc().toIso8601String(),
          'capacity': capacity,
          'points': points,
        }),
      ),
      'Failed to create the event',
    );
    return OrgEventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<OrgEventModel> cancelEvent(String id) async {
    final data = _decode(
      await http.post(_url('/events/$id/cancel'), headers: await _headers()),
      'Failed to cancel the event',
    );
    return OrgEventModel.fromJson(data['event'] as Map<String, dynamic>);
  }

  Future<({OrgEventModel event, List<OrgAttendee> attendees})> fetchAttendees(String id) async {
    final data = _decode(
      await http.get(_url('/events/$id/attendees'), headers: await _headers()),
      'Failed to load attendees',
    );
    return (
      event: OrgEventModel.fromJson(data['event'] as Map<String, dynamic>),
      attendees: ((data['attendees'] ?? []) as List)
          .map((a) => OrgAttendee.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  // ข้อความ QR ปัจจุบัน + อีกกี่ ms ต้องขอใหม่
  Future<({String payload, int expiresInMs})> fetchQr(String id) async {
    final data = _decode(
      await http.get(_url('/events/$id/qr'), headers: await _headers()),
      'Failed to load the QR code',
    );
    return (payload: (data['payload'] ?? '') as String, expiresInMs: (data['expiresInMs'] as num?)?.toInt() ?? 30000);
  }

  // ---- แอดมิน ----
  Future<List<OrgRequest>> fetchRequests(String status) async {
    final data = _decode(
      await http.get(_url('/admin/requests?status=$status'), headers: await _headers()),
      'Failed to load organization requests',
    );
    return ((data['requests'] ?? []) as List).map((r) => OrgRequest.fromJson(r as Map<String, dynamic>)).toList();
  }

  // action: approve / reject / suspend
  Future<void> decide(String userId, String action, {String note = ''}) async {
    _decode(
      await http.post(
        _url('/admin/$userId/decide'),
        headers: await _headers(),
        body: jsonEncode({'action': action, 'note': note}),
      ),
      'Failed to update this organization',
    );
  }
}
