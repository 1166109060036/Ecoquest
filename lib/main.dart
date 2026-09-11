import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/quest_provider.dart';
import 'providers/fridge_provider.dart';
import 'providers/achievement_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/party_provider.dart';
import 'routes/app_routes.dart';
import 'services/app_photo_storage.dart';

void main() async {
  // ต้อง ensureInitialized ก่อนเรียก plugin ใดๆ (path_provider) ตอนแอพยังไม่เริ่ม
  WidgetsFlutterBinding.ensureInitialized();
  // เตรียมโฟลเดอร์เก็บรูปถาวรให้พร้อมก่อน — resolve() ของ AppPhotoStorage เป็น sync
  // ต้อง init ให้เสร็จก่อน widget แรกที่อาจวาดรูปจะ build
  await AppPhotoStorage.init();
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
        ChangeNotifierProvider(create: (_) => PartyProvider()),
      ],
      child: MaterialApp(
        title: 'EcoQuest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        initialRoute: '/splash',
        routes: appRoutes,
      ),
    );
  }
}
