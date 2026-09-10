import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party_model.dart';
import '../providers/party_provider.dart';

// กด "Join" บนการ์ดห้องปาร์ตี้ — ใช้ร่วมกันทั้งหน้า Explore และแผ่น Explore ในหน้า Home
// (เหมือน handleQuestCompleted ใน quest_completion.dart ที่แชร์กันหลายหน้า)
Future<void> joinPartyRoom(
  BuildContext context,
  PartyRoomModel room, {
  VoidCallback? onJoined,
}) async {
  final partyProvider = context.read<PartyProvider>();
  final ok = await partyProvider.join(room.id);

  if (!context.mounted) return;

  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(partyProvider.errorMessage ?? 'Failed to join this party')),
    );
    return;
  }

  // ลิสต์ห้อง (จำนวนคนเข้าร่วม/isFull) เปลี่ยนแล้ว โหลดใหม่ให้การ์ดที่เหลือใน Explore อัปเดตตาม
  await partyProvider.loadRooms();
  onJoined?.call();
}
