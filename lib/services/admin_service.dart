import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก /api/admin/* ทั้งหมด — dev/QA เท่านั้น เข้าได้เฉพาะอีเมลใน ADMIN_EMAILS ฝั่ง backend
// (ดู backend/middleware/admin.js) ถ้าไม่ใช่ admin backend จะตอบ 403 ทุกเมธอดในไฟล์นี้
class AdminService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<dynamic> _get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/admin$path'),
      headers: await _headers(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Admin request failed');
    }
    return data;
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/admin$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Admin request failed');
    }
    return data;
  }

  // ---- User ----
  Future<Map<String, dynamic>> debugMe() async => (await _get('/debug/me'))['user'];

  Future<void> setUserStats({int? points, int? xp, int? level}) => _post('/user/stats', {
        if (points != null) 'points': points,
        if (xp != null) 'xp': xp,
        if (level != null) 'level': level,
      });

  Future<void> setBoost(String color, int minutes) =>
      _post('/user/boost', {'color': color, 'minutes': minutes});

  Future<void> clearBoosts() => _post('/user/boost/clear');

  Future<void> resetAccount() => _post('/user/reset');

  // ---- Quest ----
  Future<void> forceCompleteQuest(String questId) => _post('/quests/$questId/force-complete');

  Future<void> resetQuestsToday() => _post('/quests/reset-today');

  Future<void> resetQuestsAll() => _post('/quests/reset-all');

  // ---- Party ----
  Future<List<Map<String, dynamic>>> listParties() async {
    final data = await _get('/parties');
    return List<Map<String, dynamic>>.from(data['parties']);
  }

  Future<void> forceStartParty(String partyId) => _post('/parties/$partyId/force-start');

  Future<void> forceCompleteParty(String partyId) => _post('/parties/$partyId/force-complete');

  // ---- Achievement ----
  Future<void> unlockAchievement(String medalType) => _post('/achievements/$medalType/unlock');

  Future<void> resetAchievements() => _post('/achievements/reset');

  // ---- Inventory ----
  Future<void> grantItem(String itemType, int quantity) =>
      _post('/inventory/grant', {'itemType': itemType, 'quantity': quantity});

  Future<void> resetInventory() => _post('/inventory/reset');

  // ---- Upgrade ----
  Future<void> setUpgradeLevel(String upgradeType, int level) =>
      _post('/upgrades/set-level', {'upgradeType': upgradeType, 'level': level});

  // ---- Notification ----
  Future<void> testNotification(String type) => _post('/notifications/test', {'type': type});

  // ---- Fridge ----
  Future<void> addTestFridgeItem(String itemName, int expiresInHours) => _post('/fridge/add-test-item', {
        'itemName': itemName,
        'expiresInHours': expiresInHours,
      });
}
