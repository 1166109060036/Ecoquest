import 'package:flutter/material.dart';
import '../pages/auth/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/inventory/camera_page.dart';
import '../pages/inventory/fridge_page.dart';
import '../pages/main_shell.dart';
import '../pages/notification/notification_page.dart';
import '../pages/party/create_party_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/change_password_page.dart';
import '../pages/settings/upgrade_account_page.dart';

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
  // ไม่มี preselected quest ตรงนี้ — ใช้ตอนกด "Create Party" จากหน้า Party -> Browse Rooms
  // (ถ้ากดมาจากการ์ด quest ใน Explore/Home จะ push ผ่าน MaterialPageRoute พร้อม quest แทน)
  '/party/create': (context) => const CreatePartyPage(),
  '/fridge': (context) => const FridgePage(),
  '/camera': (context) => const CameraPage(),
  '/change-password': (context) => const ChangePasswordPage(),
  '/upgrade-account': (context) => const UpgradeAccountPage(),
  '/forgot-password': (context) => const ForgotPasswordPage(),
};
