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
}
