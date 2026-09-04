import 'package:flutter/material.dart';

// TODO: ต่อกับ Party/Community Quest ฝั่ง backend ตอนมี API แล้ว
class PartyPage extends StatelessWidget {
  const PartyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party')),
      body: const Center(
        child: Text('ยังไม่มีกิจกรรมกลุ่ม — เร็วๆ นี้'),
      ),
    );
  }
}
