import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// เก็บรูป "EcoQuest Moment" ที่ถ่ายจากไอเทม Camera
//
// ⚠️ เก็บไว้ในเครื่องอย่างเดียว ไม่ได้อัปขึ้น server — และไฟล์อยู่ในโฟลเดอร์ temp/cache ของแอพ
// เพราะโปรเจคยังไม่มี path_provider เลยขอ documents directory ไม่ได้
// ถ้าระบบเคลียร์ cache รูปจะหาย (โค้ดกรองรูปที่ไฟล์หายไปแล้วออกให้อัตโนมัติ)
// TODO: ลง path_provider แล้วย้ายไป getApplicationDocumentsDirectory() หรืออัปขึ้น server
class PhotoStorageService {
  Future<Directory> _photoDir() async {
    final dir = Directory('${Directory.systemTemp.path}/ecoquest_moments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // เขียนไฟล์รูปที่ตกแต่งแล้วลงเครื่อง + จำ path ไว้ คืน path ที่บันทึก
  Future<String> savePhoto(List<int> pngBytes) async {
    final dir = await _photoDir();
    final file = File('${dir.path}/moment_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(pngBytes);

    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(AppConstants.cameraPhotosKey) ?? [];
    // ใส่ไว้หน้าสุด รูปล่าสุดจะได้ขึ้นก่อน
    paths.insert(0, file.path);
    await prefs.setStringList(AppConstants.cameraPhotosKey, paths);

    return file.path;
  }

  // คืนเฉพาะรูปที่ไฟล์ยังอยู่จริง แล้วเขียนลิสต์ที่กรองแล้วกลับไปด้วย
  // (กันลิสต์บวมด้วย path ของไฟล์ที่โดนเคลียร์ cache ไปแล้ว)
  Future<List<String>> loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(AppConstants.cameraPhotosKey) ?? [];

    final existing = <String>[];
    for (final path in paths) {
      if (await File(path).exists()) existing.add(path);
    }

    if (existing.length != paths.length) {
      await prefs.setStringList(AppConstants.cameraPhotosKey, existing);
    }
    return existing;
  }

  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(AppConstants.cameraPhotosKey) ?? [];
    paths.remove(path);
    await prefs.setStringList(AppConstants.cameraPhotosKey, paths);
  }
}
