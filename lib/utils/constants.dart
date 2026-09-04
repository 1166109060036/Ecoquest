class AppConstants {
  // เปลี่ยนเป็น URL จริงตอน deploy backend แล้ว
  // ถ้ารันบน Android emulator ให้ใช้ 10.0.2.2 แทน localhost
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';

  // path รูปพื้นหลังหน้า Profile — เอารูปจริงมาวางที่ assets/images/profile_bg.jpg
  // แล้วเพิ่ม assets: - assets/images/ ใน pubspec.yaml (ดู README)
  // ถ้ายังไม่มีไฟล์ ระบบจะ fallback เป็นพื้นหลัง gradient ให้อัตโนมัติ
  static const String profileBgAsset = 'lib/utils/assets/background.png';
}
