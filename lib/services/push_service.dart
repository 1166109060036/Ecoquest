import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'api_http.dart' as http;
import '../utils/constants.dart';
import 'storage_service.dart';

// Push notification ผ่าน Firebase Cloud Messaging (19 ต.ค. 2026) — แจ้งเตือนเด้งบนหน้าจอแม้ปิดแอพอยู่
//
// backend ส่ง push ทุกครั้งที่สร้างแจ้งเตือนในแอพใบใหม่ (backend/utils/notifications.js#createNotification)
// เนื้อหาเดียวกับในหน้า Notification เลยไม่ต้องมี logic แยก แอพแค่:
// 1. ส่ง Firebase Installation ID (FID) ของเครื่องไปให้ backend ตอนเข้าแอพ (attach) / ลบออกตอน logout (detach)
//    (firebase_messaging 17 เลิกใช้ getToken() แล้ว — ใช้ register() + onRegistered ที่ได้ FID แทน)
// 2. แอพเปิดอยู่ (foreground) Android ไม่โชว์ push ให้เอง → onForegroundMessage ให้ MainShell โหลดแจ้งเตือนใหม่
//    (เล่นเสียง + จุดแดงตามระบบเดิม) แล้วโชว์ฟองข้อความแทน
// 3. ผู้ใช้แตะแจ้งเตือนบนหน้าจอ → เปิดหน้า Notification
//
// ⚠️ ต้องมี android/app/google-services.json (จาก Firebase Console) ถึงจะทำงาน — ไม่มีไฟล์ = initializeApp
// พัง → _available false แล้วทุกเมธอดในนี้กลายเป็นไม่ทำอะไรเลย แอพส่วนอื่นยังใช้ได้ปกติ
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  // ใส่ให้ MaterialApp ใน main.dart — ใช้เปิดหน้า Notification ตอนแตะ push (ไม่มี BuildContext ให้ใช้ตรงนั้น)
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final StorageService _storage = StorageService();
  bool _available = false;
  // FID ล่าสุดที่ FCM ให้มา — จำไว้ใช้ลบออกจาก backend ตอน logout
  String? _fid;
  // แตะ push ตอนแอพปิดสนิท/ยังไม่ login → จำไว้แล้วค่อยเปิดหน้า Notification ตอน MainShell พร้อม
  bool _pendingOpen = false;
  // null = ยังไม่ login (ไม่มี MainShell) — ใช้เป็นตัวบอกด้วยว่าควรส่ง FID ให้ backend ไหม
  void Function(RemoteMessage message)? _onForegroundMessage;

  // เรียกใน main() ก่อน runApp — ไม่ throw ไม่ว่ากรณีไหน
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('[push] Firebase not configured, push disabled: $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    messaging.onRegistered.listen((fid) {
      _fid = fid;
      if (_onForegroundMessage != null) _sendFid(fid);
    });
    FirebaseMessaging.onMessage.listen((message) => _onForegroundMessage?.call(message));
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotifications());
    try {
      if (await messaging.getInitialMessage() != null) _pendingOpen = true;
    } catch (_) {}
  }

  // MainShell เรียกตอนเข้าแอพ (login แล้วแน่นอน) — ขอสิทธิ์แจ้งเตือน (Android 13+ เด้งถามครั้งแรกครั้งเดียว)
  // แล้ว register() กับ FCM → onRegistered ส่ง FID ให้ backend (ส่งซ้ำทุกครั้งที่เข้าแอพไม่เสียหาย backend upsert)
  Future<void> attach({required void Function(RemoteMessage message) onForegroundMessage}) async {
    _onForegroundMessage = onForegroundMessage;
    if (!_available) return;

    if (_pendingOpen) {
      _pendingOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNotifications());
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // เคยได้ FID มาแล้ว (เช่น logout แล้ว login บัญชีใหม่โดยไม่ปิดแอพ) ส่งเลยไม่ต้องรอ onRegistered
      if (_fid != null) _sendFid(_fid!);
      await messaging.register();
    } catch (e) {
      // ลงทะเบียนไม่ได้ (เน็ตหลุด/ไม่มี Google Play services) แค่ไม่ได้ push รอบนี้ — เข้าแอพครั้งหน้าลองใหม่เอง
      debugPrint('[push] register failed: $e');
    }
  }

  // AuthProvider เรียกก่อนลบ session (ต้องใช้ JWT เดิมยิง API) — ไม่ให้แจ้งเตือนของบัญชีเก่าเด้งเข้าเครื่องนี้อีก
  // ไม่รอ backend นานเกิน 5 วิ (Render หลับอยู่ปุ่ม logout จะค้าง) — ถึงลบที่ backend ไม่ทัน unregister() ทำให้
  // FID นี้ใช้ไม่ได้แล้วอยู่ดี ส่งรอบหน้า FCM ตอบ not-registered แล้ว backend ลบทิ้งเอง (utils/push.js)
  Future<void> detach() async {
    _onForegroundMessage = null;
    if (!_available) return;

    final fid = _fid;
    if (fid != null) {
      try {
        final authToken = await _storage.getToken();
        await http
            .delete(
              Uri.parse('${AppConstants.baseUrl}/notifications/push-id'),
              headers: {'Authorization': 'Bearer $authToken', 'Content-Type': 'application/json'},
              body: jsonEncode({'fid': fid}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
    _fid = null;
  }

  // ไม่ throw — ส่งไม่ได้แค่ไม่ได้ push จนกว่าจะเข้าแอพครั้งหน้า
  Future<void> _sendFid(String fid) async {
    try {
      final authToken = await _storage.getToken();
      if (authToken == null) return;
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/notifications/push-id'),
        headers: {'Authorization': 'Bearer $authToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'fid': fid}),
      );
    } catch (e) {
      debugPrint('[push] send FID failed: $e');
    }
  }

  void _openNotifications() {
    if (_onForegroundMessage == null) {
      _pendingOpen = true;
      return;
    }
    navigatorKey.currentState?.pushNamed('/notifications');
  }
}
