import 'package:flutter/material.dart';
import '../models/fridge_item_model.dart';
import '../services/fridge_service.dart';

// ถือรายการของในตู้เย็น + ของที่ยังกรอกค้างอยู่ (ยังไม่ได้ Save)
class FridgeProvider extends ChangeNotifier {
  final FridgeService _fridgeService = FridgeService();

  List<FridgeItemModel> _items = [];
  // ของที่ผู้ใช้เพิ่งกรอกแต่ยังไม่ได้กด Save — เก็บไว้ในหน่วยความจำก่อน
  final List<FridgeItemDraft> _drafts = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<FridgeItemModel> get items => _items;
  List<FridgeItemDraft> get drafts => List.unmodifiable(_drafts);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasDrafts => _drafts.isNotEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> loadItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _fridgeService.fetchItems();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  void addDraft(FridgeItemDraft draft) {
    _drafts.add(draft);
    notifyListeners();
  }

  void removeDraft(int index) {
    if (index < 0 || index >= _drafts.length) return;
    _drafts.removeAt(index);
    notifyListeners();
  }

  void clearDrafts() {
    _drafts.clear();
    notifyListeners();
  }

  // บันทึกของที่กรอกไว้ทั้งหมดขึ้น server — true = สำเร็จ
  Future<bool> saveDrafts() async {
    if (_drafts.isEmpty) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fridgeService.addItems(_drafts);
      _drafts.clear();
      _items = await _fridgeService.fetchItems();
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    _errorMessage = null;

    try {
      await _fridgeService.deleteItem(id);
      _items = _items.where((i) => i.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
