import 'dart:io';
import 'package:path_provider/path_provider.dart';

// เจ้าของโฟลเดอร์รูปถาวรของทั้งแอพ — ทุกฟีเจอร์ที่ต้องเก็บรูปผู้ใช้ (ของในตู้เย็น,
// EcoQuest Moment, รูปโปรไฟล์) เรียกผ่านตัวนี้ตัวเดียว แทนที่จะใช้ path ที่ image_picker
// คืนมาตรงๆ (ซึ่งเป็น path ใน cache — ระบบเคลียร์ทิ้งเมื่อไหร่ก็ได้)
//
// เก็บใน DB/SharedPreferences เป็น "ชื่อไฟล์" เท่านั้น ไม่ใช่ absolute path เพราะ
// path เต็มของ documents directory เปลี่ยนได้ (เช่น iOS เปลี่ยน UUID ของ container
// ทุกครั้งที่ลงแอพใหม่) — resolve() ค่อยต่อ path เต็มให้ตอนจะใช้จริง
//
// ⚠️ รองรับค่าเก่าที่เคยเก็บเป็น absolute path เต็มไว้ก่อนหน้านี้ด้วย (ดู resolve())
// เพราะมีข้อมูลแบบนั้นอยู่แล้วทั้งใน DB และใน SharedPreferences — ห้ามลบ shim นี้ทิ้ง
class AppPhotoStorage {
  static const _folder = 'photos';
  static String? _rootPath;

  // เรียกครั้งเดียวก่อน runApp() — cache path ของ documents directory ไว้
  // เพราะ resolve() ต้องเป็น sync (ถูกเรียกจาก build() ของ widget ตรงๆ)
  static Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${docsDir.path}/$_folder');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    _rootPath = photoDir.path;
  }

  // copy ไฟล์จาก path ชั่วคราว (เช่นที่ image_picker คืนมา) เข้าที่เก็บถาวร
  // คืน "ชื่อไฟล์" ที่เอาไปเก็บลง DB/SharedPreferences ได้
  static Future<String> save(String sourcePath, {String prefix = 'photo'}) async {
    final source = File(sourcePath);
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await source.copy('$_root/$filename');
    return filename;
  }

  // เขียน bytes ที่ render เองลงเป็นไฟล์ถาวรโดยตรง (ใช้กับ EcoQuest Moment ที่ได้มาเป็น PNG bytes)
  static Future<String> saveBytes(List<int> bytes, {String prefix = 'photo'}) async {
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    await File('$_root/$filename').writeAsBytes(bytes);
    return filename;
  }

  // แปลงค่าที่เก็บไว้ (ชื่อไฟล์ใหม่ หรือ absolute path เก่า) ให้เป็น absolute path ที่ใช้เปิดไฟล์ได้จริง
  // ต้อง sync เพราะถูกเรียกตรงๆ ใน build() (File(...), FileImage(...))
  static String resolve(String stored) {
    // path เก่ามี "/" อยู่ในตัวเสมอ (มาจาก cache dir เต็มๆ) ส่วนชื่อไฟล์ใหม่ไม่มี
    if (stored.contains('/') || stored.contains('\\')) {
      return stored;
    }
    return '$_root/$stored';
  }

  static Future<void> delete(String? stored) async {
    if (stored == null) return;
    final file = File(resolve(stored));
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String get _root {
    final root = _rootPath;
    if (root == null) {
      throw StateError('AppPhotoStorage.init() must be called before use (see main.dart)');
    }
    return root;
  }
}
