import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/inventory_item_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// ดึงไอเทมของผู้เล่น (Camera/Fridge เป็นไอเทมตั้งต้นที่ backend แจกให้อัตโนมัติ)
class InventoryService {
  final StorageService _storage = StorageService();

  Future<List<InventoryItemModel>> fetchInventory() async {
    final token = await _storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/inventory'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load inventory');
    }

    return (data['items'] as List)
        .map((i) => InventoryItemModel.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  // ซื้อไอเทม 1 ชิ้นด้วย Points (ตอนนี้มีแค่ไอเทม Energy ที่ซื้อได้)
  Future<void> buyItem(String itemType) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/inventory/$itemType/buy'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to buy this item');
    }
  }

  // ใช้ไอเทม 1 ชิ้น — หักจาก inventory แล้วใส่ผลทันทีฝั่ง backend
  Future<void> useItem(String itemType) async {
    final token = await _storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/inventory/$itemType/use'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to use this item');
    }
  }

  // ใส่/ถอดของตกแต่งโปรไฟล์ — patch เช่น {'frame': 'frame_gold'} (ใส่) หรือ {'frame': null} (ถอด)
  // ผลลัพธ์จริง (cosmetics ทั้ง 4 ช่อง) มาจาก AuthProvider.refreshProfile() ที่ผู้เรียกต้องยิงต่อเอง
  // ไม่ได้อ่านจาก response ตรงนี้ (เหมือน buyItem/useItem ที่ให้หน้า Profile รีเฟรชแต้มเอง)
  Future<void> equipCosmetics(Map<String, String?> patch) async {
    final token = await _storage.getToken();
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/inventory/cosmetics'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(patch),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to update cosmetics');
    }
  }
}
