import 'package:flutter/material.dart';
import '../models/inventory_item_model.dart';
import '../services/inventory_service.dart';

// ถือรายการไอเทมไว้ให้หน้า Inventory ใช้ — โหลดครั้งเดียวตอนเข้าแอพ
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service = InventoryService();

  List<InventoryItemModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<InventoryItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInventory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _service.fetchInventory();
    } catch (e) {
      // โหลดไอเทมไม่ได้ไม่ควรทำให้หน้า Inventory พัง — ปล่อยเป็นลิสต์ว่างไปก่อน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }
}
