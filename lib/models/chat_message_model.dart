// ข้อความแชท 1 ข้อความ — ข้อมูลจริงจาก GET /api/chat/<channel>/messages (ประวัติ) และ event
// 'chat:message' ที่มาจาก WebSocket แบบ real-time (ดู chat_socket_service.dart) ทั้งคู่ใช้โครงเดียวกัน
class ChatMessageModel {
  final String id;
  final String channelType; // 'world' / 'party' / 'friend'
  final String channelId;
  final String fromUserId;
  final String fromDisplayName;
  final String text;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.channelType,
    required this.channelId,
    required this.fromUserId,
    required this.fromDisplayName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] ?? '').toString(),
      channelType: json['channelType'] ?? 'world',
      channelId: (json['channelId'] ?? '').toString(),
      fromUserId: (json['fromUserId'] ?? '').toString(),
      fromDisplayName: json['fromDisplayName'] ?? 'Player',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
