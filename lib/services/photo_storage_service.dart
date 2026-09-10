import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'app_photo_storage.dart';

// เก็บรูป "EcoQuest Moment" ที่ถ่ายจากไอเทม Camera
//
// ไฟล์จริงเก็บผ่าน AppPhotoStorage (documents directory — ถาวร ไม่หายตอนเคลียร์ cache)
// ส่วนตัวนี้แค่จำลิสต์ "ชื่อไฟล์" ไว้ใน SharedPreferences ตามลำดับที่ถ่าย
//
// ⚠️ migration: ก่อนหน้านี้เคยเก็บเป็น absolute path เต็มไว้ใน temp/cache — loadPhotos()
// เป็นจุดที่กู้ของเก่าเหล่านั้นมาเก็บถาวรให้อัตโนมัติ (ถ้าไฟล์ยังไม่โดนเคลียร์ไปก่อน)
class PhotoStorageService {
  // เขียนไฟล์รูปที่ตกแต่งแล้วลงเครื่องแบบถาวร + จำชื่อไฟล์ไว้ คืน absolute path ที่บันทึก
  // (คืน absolute path ไม่ใช่ชื่อไฟล์ เพื่อให้ผู้เรียกใช้ต่อกับ Image.file/Gal.putImage ได้ตรงๆ
  // เหมือนพฤติกรรมเดิม — คนเรียกไม่ต้องรู้เรื่อง resolve())
  Future<String> savePhoto(List<int> pngBytes) async {
    final filename = await AppPhotoStorage.saveBytes(pngBytes, prefix: 'moment');

    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(AppConstants.cameraPhotosKey) ?? [];
    // ใส่ไว้หน้าสุด รูปล่าสุดจะได้ขึ้นก่อน
    names.insert(0, filename);
    await prefs.setStringList(AppConstants.cameraPhotosKey, names);

    return AppPhotoStorage.resolve(filename);
  }

  // คืน absolute path ของรูปที่ยังมีไฟล์อยู่จริงเท่านั้น (เรียงล่าสุดก่อน)
  // ระหว่างทางยัง migrate ค่าเก่าที่เป็น absolute path เต็ม (ของก่อนอัปเดตนี้) มาเก็บถาวรให้ด้วย
  Future<List<String>> loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(AppConstants.cameraPhotosKey) ?? [];

    final resolvedNames = <String>[];
    var changed = false;

    for (final entry in stored) {
      final isLegacyPath = entry.contains('/') || entry.contains('\\');

      if (!isLegacyPath) {
        // ชื่อไฟล์ใหม่ปกติ — เช็คแค่ว่าไฟล์ยังอยู่จริงไหม
        if (await File(AppPhotoStorage.resolve(entry)).exists()) {
          resolvedNames.add(entry);
        } else {
          changed = true; // ไฟล์หายไปแล้ว ตัดออกจากลิสต์
        }
        continue;
      }

      // ค่าเก่า: absolute path เต็มในโฟลเดอร์ temp — ถ้าไฟล์ยังไม่โดนเคลียร์ ให้กู้มาเก็บถาวร
      final legacyFile = File(entry);
      if (await legacyFile.exists()) {
        final migrated = await AppPhotoStorage.save(entry, prefix: 'moment');
        resolvedNames.add(migrated);
      }
      // ไม่ว่าจะ migrate สำเร็จหรือไฟล์หายไปแล้ว ค่าเก่าตัวนี้ต้องไม่เก็บซ้ำอีก
      changed = true;
    }

    if (changed) {
      await prefs.setStringList(AppConstants.cameraPhotosKey, resolvedNames);
    }

    return resolvedNames.map(AppPhotoStorage.resolve).toList();
  }

  // path ที่รับมาเป็น absolute path (ตามที่ loadPhotos/savePhoto คืนให้) — แปลงกลับเป็น
  // ชื่อไฟล์ก่อนหาตัวเทียบในลิสต์ที่เก็บไว้ เพราะ SharedPreferences เก็บแค่ชื่อไฟล์
  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    // ใช้ "/" ตรงๆ ไม่ใช้ Platform.pathSeparator เพราะ AppPhotoStorage ต่อ path ด้วย "/"
    // เสมอไม่ว่าจะรันบน platform ไหน (ดู AppPhotoStorage.resolve)
    final filename = path.split('/').last;
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(AppConstants.cameraPhotosKey) ?? [];
    names.removeWhere((n) => n == filename || n == path);
    await prefs.setStringList(AppConstants.cameraPhotosKey, names);
  }
}
