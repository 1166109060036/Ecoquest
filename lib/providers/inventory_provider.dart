import 'package:flutter/material.dart';
import '../models/inventory_item_model.dart';
import '../services/inventory_service.dart';

// ถือรายการไอเทมไว้ให้หน้า Inventory ใช้ — โหลดครั้งเดียวตอนเข้าแอพ
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service = InventoryService();

  List<InventoryItemModel> _items = [];
  bool _isLoading = false;
  // itemType ที่กำลังซื้อ/ใช้อยู่ตอนนี้ (null = ไม่มี) — ใช้ปิดปุ่มเฉพาะการ์ดนั้นระหว่างรอ backend ตอบ
  // ไม่ใช้ bool เดียวรวมทุกการ์ด เพราะกดซื้อไอเทมนึงไม่ควรทำให้ปุ่มไอเทมอื่นกดไม่ได้ไปด้วย
  String? _busyItemType;
  String? _errorMessage;

  List<InventoryItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get busyItemType => _busyItemType;
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

  // ซื้อไอเทม 1 ชิ้นด้วย Points แล้วโหลด inventory ใหม่ (quantity/cost อาจเปลี่ยน)
  // ผู้เรียก (หน้า Profile) ต้อง refreshProfile() ต่อเองด้วย เพราะยอดแต้มอยู่ใน AuthProvider คนละตัว
  Future<bool> buyItem(String itemType) async {
    _busyItemType = itemType;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.buyItem(itemType);
      await loadInventory();
      _busyItemType = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _busyItemType = null;
      notifyListeners();
      return false;
    }
  }

  // ใช้ไอเทม 1 ชิ้น แล้วโหลด inventory ใหม่ (quantity ลดลง 1)
  Future<bool> useItem(String itemType) async {
    _busyItemType = itemType;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.useItem(itemType);
      await loadInventory();
      _busyItemType = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _busyItemType = null;
      notifyListeners();
      return false;
    }
  }
}
