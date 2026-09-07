import 'package:flutter/material.dart';
import '../models/quest_card_model.dart';
import '../models/quest_history_model.dart';
import '../services/quest_service.dart';

// ถือลิสต์ quest ไว้ที่เดียวให้ทั้งหน้า Explore และแผ่น Explore ในหน้า Home ใช้ร่วมกัน
// สำคัญ: 2 หน้านั้นอยู่ใน IndexedStack พร้อมกันตลอด ถ้าต่างคนต่าง fetch จะยิง API ซ้ำซ้อน
// และพอทำ quest สำเร็จในหน้าหนึ่ง อีกหน้าจะไม่อัปเดตตาม — เลยต้องแชร์ state กัน
class QuestProvider extends ChangeNotifier {
  final QuestService _questService = QuestService();

  List<QuestCardModel> _quests = [];
  List<QuestHistoryEntry> _history = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<QuestCardModel> get quests => _quests;
  // ประวัติ quest ที่ทำสำเร็จ ใช้โชว์ในหน้า Profile
  List<QuestHistoryEntry> get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadHistory() async {
    try {
      _history = await _questService.fetchHistory();
      notifyListeners();
    } catch (e) {
      // ประวัติโหลดไม่ได้ไม่ควรทำให้หน้า Profile พัง — ปล่อยให้เป็นลิสต์ว่างไปก่อน
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> loadQuests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _quests = await _questService.fetchQuests();
    } catch (e) {
      // ไม่ throw ต่อ — เน็ตหลุดแล้วไม่ควรทำให้แอพพัง แค่โชว์ลิสต์ว่างกับข้อความ error
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  // คืนรางวัลที่ได้กลับไปให้หน้า UI เอาไปโชว์ (null = ทำไม่สำเร็จ ดูสาเหตุที่ errorMessage)
  Future<QuestReward?> completeQuest(String questId) async {
    _errorMessage = null;

    try {
      final reward = await _questService.completeQuest(questId);
      // โหลดลิสต์ใหม่เพื่อให้ completedToday ของ quest รายวันอัปเดตตาม
      // และโหลดประวัติใหม่ด้วย เพราะเพิ่งมีรายการใหม่เพิ่มเข้าไป (หน้า Profile จะได้เห็นทันที)
      await Future.wait([loadQuests(), loadHistory()]);
      return reward;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }
}
