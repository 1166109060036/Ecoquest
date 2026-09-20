import '../utils/constants.dart';
import 'cosmetics_model.dart';

class UserModel {
  final String id;
  final String? email;
  final String displayName;
  final bool isGuest;
  // URL เต็มของรูปโปรไฟล์ (เก็บจริงเป็นไฟล์บน backend แล้ว) — null = ยังไม่ได้ตั้งรูป
  final String? avatarUrl;
  // ของตกแต่งโปรไฟล์ที่ใส่อยู่ตอนนี้ — register/login/guest ไม่ส่งค่านี้มาด้วย จะได้ค่าจริงตอน
  // เรียก GET /auth/me เหมือนฟิลด์ระบบเกมด้านล่าง
  final EquippedCosmetics cosmetics;

  // ---- ค่าระบบเกม ----
  // register/login/guest ไม่ได้ส่งค่าพวกนี้กลับมาด้วย จะได้ค่าจริงตอนเรียก GET /auth/me
  // เลยต้องมี default ไว้กัน null ตอน parse response ของ endpoint เก่าหรือ session ที่ cache ไว้ก่อนหน้า
  final int level;
  final int xp;
  final int points;
  // register/login/guest ไม่ส่งค่านี้กลับมาด้วย เลย default เป็น true (ค่าเริ่มต้นฝั่ง backend เหมือนกัน)
  final bool notificationsEnabled;
  // true เฉพาะบัญชีจริงที่อีเมลอยู่ใน ADMIN_EMAILS ฝั่ง backend — ใช้แค่โชว์/ซ่อนเมนู "Admin Tools"
  // ในหน้า Settings เท่านั้น ไม่ใช่ตัวเช็คสิทธิ์จริง (ทุก request ไป /api/admin/* ถูกเช็คซ้ำที่ backend เสมอ)
  final bool isAdmin;

  UserModel({
    required this.id,
    this.email,
    required this.displayName,
    required this.isGuest,
    this.avatarUrl,
    this.cosmetics = const EquippedCosmetics(),
    this.level = 1,
    this.xp = 0,
    this.points = 0,
    this.notificationsEnabled = true,
    this.isAdmin = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'],
      email: json['email'],
      displayName: json['displayName'] ?? 'Player',
      isGuest: json['isGuest'] ?? false,
      avatarUrl: AppConstants.resolveUrl(json['avatarUrl']),
      cosmetics: EquippedCosmetics.fromJson(json['cosmetics']),
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      points: json['points'] ?? 0,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  // ใช้ cache session ลง SharedPreferences (ดู StorageService) — ลืมใส่ฟิลด์ไหนตรงนี้ ฟิลด์นั้น
  // จะหายตอนเปิดแอพใหม่ (cold start อ่านจาก cache นี้ก่อน ไม่ได้ยิง /auth/me ทันที)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'isGuest': isGuest,
      'avatarUrl': avatarUrl,
      'cosmetics': cosmetics.toJson(),
      'level': level,
      'xp': xp,
      'points': points,
      'notificationsEnabled': notificationsEnabled,
      'isAdmin': isAdmin,
    };
  }
}
