import 'package:flutter/material.dart';

// TODO: ต่อกับ InventoryItem model ฝั่ง backend ตอนมี API แล้ว
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: const Center(
        child: Text('ยังไม่มีไอเทม — เร็วๆ นี้'),
      ),
    );
  }
}
