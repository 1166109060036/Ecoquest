import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/upgrade_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ร้าน Upgrade Ability — ดูรายการ + ซื้อ
class UpgradeService {
  final StorageService _storage = StorageService();

  Future<List<UpgradeModel>> fetchUpgrades() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/upgrades'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load upgrades');
    }

    return (data['upgrades'] as List)
        .map((u) => UpgradeModel.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  // คืน {upgrade, points} — points คือยอดคงเหลือหลังหักแล้ว เอาไปอัปเดต balance ในแอพได้ทันที
  Future<(UpgradeModel, int)> buyUpgrade(String upgradeType) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/upgrades/$upgradeType/buy'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to buy this upgrade');
    }

    return (
      UpgradeModel.fromJson(data['upgrade'] as Map<String, dynamic>),
      data['points'] as int,
    );
  }
}
