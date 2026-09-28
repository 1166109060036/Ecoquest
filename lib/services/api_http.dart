import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ตัวกลางเรียก HTTP ของทุก service — ชื่อ/รูปแบบฟังก์ชันเหมือน package:http เป๊ะ แต่ละ service เลย
// เปลี่ยนแค่บรรทัด import (`import 'api_http.dart' as http;`) ไม่ต้องแก้ทุกจุดที่เรียก
//
// เพิ่มจาก http เดิม 2 อย่าง:
// 1. timeout — เดิมไม่มีเลย ถ้า server ไม่ตอบ (Render กำลังตื่น/เน็ตมือถือหลุดกลางทาง) หน้านั้นหมุนโหลด
//    ค้างไปตลอด ตอนนี้ครบเวลาแล้ว throw ออกไปให้หน้าจอโชว์ error + ให้ผู้ใช้ปัดลง/กดลองใหม่เองได้
// 2. แปลง error ดิบเป็นข้อความที่คนอ่านเข้าใจ — เดิมผู้ใช้เห็น "ClientException with SocketException:
//    Failed host lookup..." หรือ FormatException ตอน Render ตอบหน้า HTML 502/503 กลับมาแทน JSON
//
// ทุกข้อความ throw เป็น Exception('...') เหมือนที่ service ทำอยู่แล้ว provider ที่
// replaceFirst('Exception: ', '') เลยเอาไปโชว์ได้ตรงๆ

// Render free tier ตื่นจากหลับใช้เวลาได้ถึง ~50 วิ — ตั้งไว้ยาวกว่านั้นนิดหน่อย ไม่งั้น request แรกหลัง
// server หลับจะ timeout ทั้งที่อีกไม่กี่วิ server ก็ตอบแล้ว
Duration requestTimeout = const Duration(seconds: 60);

const _timeoutMessage = 'The server is taking too long to respond. Please try again.';
const _offlineMessage = 'Cannot connect to the server. Check your internet connection and try again.';
const _serverDownMessage = 'The server is unavailable right now. Please try again in a moment.';

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    _send(() => http.get(url, headers: headers));

Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.post(url, headers: headers, body: body, encoding: encoding));

Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.put(url, headers: headers, body: body, encoding: encoding));

Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(() => http.delete(url, headers: headers, body: body, encoding: encoding));

Future<http.Response> _send(Future<http.Response> Function() request) async {
  final http.Response response;
  try {
    response = await request().timeout(requestTimeout);
  } on TimeoutException {
    throw Exception(_timeoutMessage);
  } on SocketException {
    throw Exception(_offlineMessage);
  } on http.ClientException {
    throw Exception(_offlineMessage);
  }

  // Render/proxy ตอบหน้า HTML ตอน server ล่ม/กำลัง deploy — ปล่อยไปถึง jsonDecode ใน service จะได้
  // FormatException อ่านไม่รู้เรื่อง เลยดักไว้ตรงนี้ก่อน (5xx ที่เป็น JSON จาก backend เองยังผ่านไปให้
  // service อ่าน message ตามปกติ)
  final isJson = (response.headers['content-type'] ?? '').contains('application/json');
  if (response.statusCode >= 500 && !isJson) {
    throw Exception(_serverDownMessage);
  }
  return response;
}
