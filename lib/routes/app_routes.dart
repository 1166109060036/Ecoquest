import 'package:flutter/material.dart';
import '../pages/auth/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/inventory/camera_page.dart';
import '../pages/inventory/fridge_page.dart';
import '../pages/inventory/eco_badge_page.dart';
import '../pages/main_shell.dart';
import '../pages/notification/notification_page.dart';
import '../pages/party/create_party_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/change_password_page.dart';
import '../pages/settings/upgrade_account_page.dart';
import '../pages/admin/admin_page.dart';
import '../pages/shop/shop_page.dart';

// รวม route ทั้งหมดของแอพไว้ที่เดียว เพิ่มหน้าใหม่ก็มาแก้ไฟล์นี้ไฟล์เดียว
//
// หมายเหตุ: หลัง login/register/guest/splash สำเร็จ ให้ไปที่ '/main' (MainShell)
// ไม่ใช่ '/home' อีกต่อไป — MainShell คือ Shell กลางที่ถือ bottom nav
// และสลับเนื้อหา Home/Inventory/Explore/Party/Profile อยู่ข้างในตัวเดียว
final Map<String, WidgetBuilder> appRoutes = {
  '/splash': (context) => const SplashPage(),
  '/login': (context) => const LoginPage(),
  '/register': (context) => const RegisterPage(),
  '/main': (context) => const MainShell(),
  '/settings': (context) => const SettingsPage(),
  '/notifications': (context) => const NotificationPage(),
  // เข้าจากปุ่มร้านค้าข้างปุ่มกระดิ่งมุมขวาบนของหน้า Profile
  '/shop': (context) => const ShopPage(),
  // เปิดจากปุ่ม + (FAB) มุมขวาล่างของหน้า Explore ตอนเลือก chip "Party" เท่านั้น
  // คืนค่า true กลับมาตอน pop ถ้าสร้างห้องสำเร็จ ให้ผู้เรียกเอาไปสลับไปแท็บ Party ต่อได้
  '/party/create': (context) => const CreatePartyPage(),
  '/fridge': (context) => const FridgePage(),
  // เปิดจากไอเทม Eco Badge ในหน้า Inventory เท่านั้น — ดูเหรียญ Achievement ที่ปลดล็อกแล้ว
  '/eco-badge': (context) => const EcoBadgePage(),
  '/camera': (context) => const CameraPage(),
  '/change-password': (context) => const ChangePasswordPage(),
  '/upgrade-account': (context) => const UpgradeAccountPage(),
  '/forgot-password': (context) => const ForgotPasswordPage(),
  // dev/QA เท่านั้น — เมนูเข้าถึงอยู่ในหน้า Settings โชว์เฉพาะ user.isAdmin (ดู settings_page.dart)
  '/admin': (context) => const AdminPage(),
};
