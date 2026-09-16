import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/storage_service.dart';

// ถือแชททั้ง 3 แบบ (โลก/ปาร์ตี้/เพื่อน) — เก็บข้อความแยกต่อ channel key เป็น map คีย์ด้วย message id
// กันซ้ำตอน reconnect แล้วดึงประวัติ REST ทับของที่ได้จาก socket สดๆ ไปแล้ว
// key: 'world' / 'party' / 'friend:<friendUserId>' (แชทเพื่อนต้องแยกคีย์ต่อคนคุย ไม่ใช่แค่ 'friend'
// เฉยๆ เพราะคุยกับเพื่อนได้หลายคน)
class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();
  final ChatSocketService _socketService = ChatSocketService();
  final StorageService _storage = StorageService();

  ChatConnectionStatus _status = ChatConnectionStatus.disconnected;
  ChatConnectionStatus get status => _status;

  final Map<String, Map<String, ChatMessageModel>> _messagesByChannel = {};

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _channelKey(String channelType, String channelId) =>
      channelType == 'friend' ? 'friend:$channelId' : channelType;

  List<ChatMessageModel> _messagesFor(String key) {
    final map = _messagesByChannel[key] ?? {};
    final list = map.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<ChatMessageModel> get worldMessages => _messagesFor('world');
  List<ChatMessageModel> get partyMessages => _messagesFor('party');
  List<ChatMessageModel> messagesWithFriend(String friendUserId) => _messagesFor('friend:$friendUserId');

  // เชื่อมต่อ socket แบบ lazy — เรียกตอนเปิดแท็บ Chat ครั้งแรกเท่านั้น (ไม่ใช่ตอนแอพเปิด/main_shell
  // mount) ตามแนวทางเดิมของโปรเจคที่ไม่รอ backend ตื่นก่อนเข้าแอพ (ดู AuthProvider.checkSession())
  Future<void> connect() async {
    if (_status == ChatConnectionStatus.connected || _status == ChatConnectionStatus.connecting) {
      return;
    }
    final token = await _storage.getToken();
    if (token == null) return;

    _socketService.connect(
      token: token,
      onMessage: _handleIncomingMessage,
      onStatusChange: (status) {
        _status = status;
        notifyListeners();
      },
    );
  }

  void _handleIncomingMessage(ChatMessageModel message) {
    final key = _channelKey(message.channelType, message.channelId);
    _messagesByChannel.putIfAbsent(key, () => {})[message.id] = message;
    notifyListeners();
  }

  Future<void> loadWorldHistory() => _loadHistory('world', _service.fetchWorldHistory);

  // ไม่ได้อยู่ปาร์ตี้ตอนนี้ก็แค่เงียบไว้ (errorMessage ยังตั้งไว้ให้ debug ได้ แต่ ChatTab เช็ค
  // PartyProvider.hasParty ก่อนเปิด chip Party ให้กดอยู่แล้ว ไม่ควรมีทางเรียกฟังก์ชันนี้ตอนไม่มีปาร์ตี้)
  Future<void> loadPartyHistory() => _loadHistory('party', _service.fetchPartyHistory);

  Future<void> loadFriendHistory(String friendUserId) =>
      _loadHistory('friend:$friendUserId', () => _service.fetchFriendHistory(friendUserId));

  Future<void> _loadHistory(String key, Future<List<ChatMessageModel>> Function() fetch) async {
    _isLoadingHistory = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final messages = await fetch();
      final map = _messagesByChannel.putIfAbsent(key, () => {});
      for (final m in messages) {
        map[m.id] = m;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoadingHistory = false;
    notifyListeners();
  }

  void sendWorldMessage(String text) => _send(channelType: 'world', channelId: 'world', text: text);

  // ไม่ต้องส่ง channelId — backend หา partyId เองจาก membership จริงของผู้ส่ง (กันส่งเข้าห้องผิด)
  void sendPartyMessage(String text) => _send(channelType: 'party', text: text);

  void sendFriendMessage(String friendUserId, String text) =>
      _send(channelType: 'friend', channelId: friendUserId, text: text);

  void _send({required String channelType, String? channelId, required String text}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _socketService.sendMessage(
      channelType: channelType,
      channelId: channelId,
      text: trimmed,
      onAck: (ok, error) {
        if (!ok) {
          _errorMessage = error ?? 'Failed to send message';
          notifyListeners();
        }
      },
    );
  }

  void disconnect() {
    _socketService.disconnect();
    _status = ChatConnectionStatus.disconnected;
    _messagesByChannel.clear();
    notifyListeners();
  }
}
