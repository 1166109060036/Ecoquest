import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/quest_provider.dart';
import 'providers/fridge_provider.dart';
import 'providers/achievement_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/party_provider.dart';
import 'providers/upgrade_provider.dart';
import 'providers/admin_provider.dart';
import 'routes/app_routes.dart';
import 'services/app_photo_storage.dart';
import 'services/sound_service.dart';

void main() async {
  // ต้อง ensureInitialized ก่อนเรียก plugin ใดๆ (path_provider) ตอนแอพยังไม่เริ่ม
  WidgetsFlutterBinding.ensureInitialized();
  // เตรียมโฟลเดอร์เก็บรูปถาวรให้พร้อมก่อน — resolve() ของ AppPhotoStorage เป็น sync
  // ต้อง init ให้เสร็จก่อน widget แรกที่อาจวาดรูปจะ build
  await AppPhotoStorage.init();
  // ต้องโหลดระดับเสียงที่เคยตั้งไว้ก่อนเริ่มเล่นเพลง ไม่งั้นจะดังสุดวูบนึงก่อนค่อยปรับลง
  await SoundService.instance.loadSavedVolumes();
  // ไม่ await เพราะไม่ต้องรอเพลงพร้อมก่อนเปิดหน้าแรก (ยังไม่มีไฟล์เพลงจริงก็รอไม่มีทางจบ)
  SoundService.instance.playBackgroundMusic();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QuestProvider()),
        ChangeNotifierProvider(create: (_) => FridgeProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PartyProvider()),
        ChangeNotifierProvider(create: (_) => UpgradeProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'EcoQuest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          // เล่นเสียงคลิกเฉพาะตอนแตะ widget ที่กดได้จริงๆ (ปุ่ม, InkWell ฯลฯ) เท่านั้น ไม่ใช่ทุกจุดที่
          // แตะหน้าจอเหมือนที่เคยลองด้วย Listener ก่อนหน้านี้ — ดูเหตุผลเต็มๆ ที่ SoundSplashFactory
          // ใน sound_service.dart
          splashFactory: SoundSplashFactory(InkRipple.splashFactory),
        ),
        initialRoute: '/splash',
        routes: appRoutes,
      ),
    );
  }
}
