import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../models/chat_message_model.dart';
import '../utils/constants.dart';

// สถานะการเชื่อมต่อ WebSocket — ให้ ChatTab โชว์ banner "กำลังเชื่อมต่อ..." แบบไม่บล็อก UI
// เวลา backend หลับอยู่ (Render free tier sleep หลังไม่มีคนใช้ ~15 นาที) แทนที่จะทำหน้าแชทค้าง
// (แนวทางเดียวกับที่ AuthProvider.checkSession() ไม่รอ backend ตื่นก่อนเข้าแอพ)
enum ChatConnectionStatus { connecting, connected, disconnected, reconnecting }

// ห่อ IO.Socket ของ package socket_io_client — เชื่อมต่อ/ส่ง/รับข้อความแชทแบบ real-time
// reconnect ใช้ exponential backoff ที่ตัว package มีให้อยู่แล้ว ไม่เขียน retry loop เอง
class ChatSocketService {
  sio.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  // เชื่อมต่อ — ต้อง idempotent (เรียกซ้ำตอนต่ออยู่แล้ว/กำลังต่ออยู่ต้องไม่ทำอะไรซ้ำ) กัน socket รั่ว
  // ถ้าเคย connect ไว้แล้ว ต้อง disconnect() ก่อนเสมอถ้าจะเปลี่ยน token (เช่น login คนละบัญชี)
  void connect({
    required String token,
    required void Function(ChatMessageModel message) onMessage,
    required void Function(ChatConnectionStatus status) onStatusChange,
  }) {
    if (_socket != null) return;

    // socket.io attach เข้ากับ HTTP server ตัวเดียวกันที่ path root ไม่ใช่ใต้ /api — ต้องตัด /api
    // ท้าย baseUrl ทิ้งก่อนต่อ (AppConstants.baseUrl ลงท้ายด้วย /api เสมอทั้ง dev/deployed)
    final origin = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    onStatusChange(ChatConnectionStatus.connecting);

    _socket = sio.io(
      origin,
      sio.OptionBuilder()
          .setTransports(['websocket']) // จำเป็นสำหรับแอพมือถือ (ไม่มี XHR/polling แบบเว็บ)
          .setAuth({'token': token})
          // กัน socket_io_client เอา Manager เก่าจาก cache (host เดียวกัน) มาใช้ซ้ำแบบไม่ตั้งใจ
          // ซึ่งอาจถือ token ของบัญชีก่อนหน้าค้างอยู่ — บังคับสร้างการเชื่อมต่อใหม่เสมอ
          .enableForceNew()
          .build(),
    );

    _socket!.onConnect((_) => onStatusChange(ChatConnectionStatus.connected));
    _socket!.onDisconnect((_) => onStatusChange(ChatConnectionStatus.disconnected));
    _socket!.onConnectError((_) => onStatusChange(ChatConnectionStatus.disconnected));
    _socket!.onReconnectAttempt((_) => onStatusChange(ChatConnectionStatus.reconnecting));
    _socket!.onReconnect((_) => onStatusChange(ChatConnectionStatus.connected));

    _socket!.on('chat:message', (data) {
      onMessage(ChatMessageModel.fromJson(data as Map<String, dynamic>));
    });
  }

  // ack: ok=true ส่งสำเร็จ, ok=false + error = เหตุผลจาก backend (เช่น ข้อความว่าง/ยาวเกิน)
  void sendMessage({
    required String channelType,
    String? channelId,
    required String text,
    void Function(bool ok, String? error)? onAck,
  }) {
    _socket?.emitWithAck(
      'chat:send',
      {
        'channelType': channelType,
        if (channelId != null) 'channelId': channelId,
        'text': text,
      },
      ack: (data) {
        final map = data is Map ? data : null;
        onAck?.call(map?['ok'] == true, map?['message'] as String?);
      },
    );
  }

  void disconnect() {
    // dispose() ไม่ใช่ disconnect()/close() — กัน memory leak บน iOS ตามที่ package แนะนำไว้
    _socket?.dispose();
    _socket = null;
  }
}
