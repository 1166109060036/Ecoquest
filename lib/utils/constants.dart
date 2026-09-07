class AppConstants {
  // 🔴 แก้บรรทัดนี้เป็น URL ที่ Render ให้มาหลัง deploy เสร็จ (ต้องมี /api ต่อท้าย)
  //    เช่น 'https://ecoquest-api.onrender.com/api'
  //    ตราบใดที่ยังเป็น localhost แอพจะใช้ไม่ได้ถ้าไม่ได้เปิด backend ในคอม
  static const String _deployedApiUrl = 'http://127.0.0.1:5000/api';

  // ต่อ backend ในเครื่องตอน dev โดยไม่ต้องแก้โค้ด:
  //   เครื่องจริง (+ adb reverse tcp:5000 tcp:5000):
  //     flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
  //   Android Emulator (10.0.2.2 = คอมของเรา ใช้ได้เฉพาะ emulator):
  //     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _deployedApiUrl,
  );

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
  // เก็บ path รูปที่ถ่ายจากไอเทม Camera (เก็บแค่ในเครื่อง ไม่ได้อัปขึ้น server)
  static const String cameraPhotosKey = 'camera_photos';

  // path รูปพื้นหลังหน้า Profile — ไฟล์จริงอยู่ที่ lib/utils/assets/background.png
  // ต้องตรงกับ path ที่ประกาศไว้ใน pubspec.yaml (assets:) เป๊ะๆ ทุกตัวอักษร
  // ถ้ายังไม่มีไฟล์ ระบบจะ fallback เป็นพื้นหลัง gradient ให้อัตโนมัติ
  static const String profileBgAsset = 'lib/utils/assets/background.png';
}
