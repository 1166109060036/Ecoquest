import 'package:flutter/material.dart';

// TODO: ต่อกับ Quest model ฝั่ง backend ตอนมี API แล้ว — หน้านี้ไว้ให้ดู/หา Quest ใหม่
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: const Center(
        child: Text('ยังไม่มี Quest ให้สำรวจ — เร็วๆ นี้'),
      ),
    );
  }
}
