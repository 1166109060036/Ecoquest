class AppConstants {
  // เปลี่ยนเป็น URL จริงตอน deploy backend แล้ว
  // ถ้ารันบน Android emulator ให้ใช้ 10.0.2.2 แทน localhost
  static const String baseUrl = 'http://localhost:5000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
