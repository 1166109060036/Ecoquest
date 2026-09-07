import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fridge_item_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

// เรียก API ของในตู้เย็นทั้งหมด — ทุก endpoint ต้องแนบ token เพราะเป็นข้อมูลรายบุคคล
class FridgeService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _headers({bool withBody = false}) async {
    final token = await _storage.getToken();
    return {
      if (withBody) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<FridgeItemModel>> fetchItems() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/fridge-items'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to load fridge items');
    }

    return (data['items'] as List)
        .map((i) => FridgeItemModel.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  // ส่งของที่กรอกไว้ทั้งชุดทีเดียว (backend รับเป็น array อยู่แล้ว)
  Future<List<FridgeItemModel>> addItems(List<FridgeItemDraft> drafts) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/fridge-items'),
      headers: await _headers(withBody: true),
      body: jsonEncode({'items': drafts.map((d) => d.toJson()).toList()}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to save fridge items');
    }

    return (data['items'] as List)
        .map((i) => FridgeItemModel.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteItem(String id) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/fridge-items/$id'),
      headers: await _headers(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to remove item');
    }
  }
}
