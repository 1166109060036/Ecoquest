class AppConstants {
  // backend ที่ deploy อยู่บน Render (แอพใช้ตัวนี้เป็นค่าเริ่มต้น = ไม่ต้องเปิดคอมแล้ว)
  static const String _deployedApiUrl = 'https://ecoquest-api-71cl.onrender.com/api';

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

  // backend ส่ง path รูปโปรไฟล์มาแบบสั้นๆ (เช่น /users/<id>/avatar?v=...) ต้องต่อ baseUrl
  // ให้เป็น URL เต็มก่อนเอาไปใช้กับ Image.network — ใช้ตัวนี้ร่วมกันทุกโมเดลที่มี avatarUrl
  // (UserModel, PartyMemberModel, PublicProfileModel) กันโค้ดต่อ URL ซ้ำกันหลายที่
  //
  // เช็คว่ามี "http" นำหน้าหรือยังก่อนต่อ เพราะค่าที่ cache ไว้ใน SharedPreferences (ผ่าน
  // UserModel.toJson) จะเป็น URL เต็มอยู่แล้ว ถ้าต่อซ้ำอีกทีตอนโหลด session เก่าจะได้ URL
  // ผิดซ้อนกัน 2 ชั้น
  static String? resolveUrl(String? path) {
    if (path == null) return null;
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}
