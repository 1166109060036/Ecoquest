import 'package:flutter/material.dart';
import '../models/party_model.dart';
import '../utils/date_format.dart';
import 'quest_card.dart'; // ใช้ DifficultyChip ตัวเดียวกับ QuestCard

// การ์ดห้องปาร์ตี้ที่เปิดให้เข้าร่วมได้ ใช้ในลิสต์ Explore (โทนสว่าง)
// ตั้งใจให้หน้าตาเหมือน QuestCard เป๊ะๆ เพราะโชว์ปนกันอยู่ในลิสต์เดียวกันตอนเลือก chip "All"
// (คนละ widget กับ _RoomTile เดิมในหน้า Party ที่เป็นโทนมืด/กระจก — ย้ายมาไว้ที่นี่แทนแล้ว)
class PartyRoomCard extends StatelessWidget {
  final PartyRoomModel room;
  final bool isJoined; // ห้องนี้คือห้องที่ฉันอยู่อยู่แล้วหรือเปล่า
  final VoidCallback? onJoin;

  const PartyRoomCard({super.key, required this.room, required this.isJoined, this.onJoin});

  String get _actionLabel => isJoined ? 'Joined' : (room.isFull ? 'Full' : 'Join');
  bool get _actionEnabled => !isJoined && !room.isFull;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoomThumbnail(imageAsset: room.quest.coverImageAsset),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${room.quest.scorePoints.toString().padLeft(3, '0')} P',
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Party',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  room.quest.title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DifficultyChip(difficulty: room.quest.difficulty),
                    const SizedBox(width: 6),
                    Expanded(child: _RoomInfoColumn(room: room)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _actionEnabled ? onJoin : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        elevation: 0,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_actionLabel, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// วันเวลา + สถานที่ + จำนวนคน — 3 บรรทัดยัดในพื้นที่แคบเท่า _PartyEventInfoRow ของ QuestCard
// (โดนบีบด้วย DifficultyChip ด้านซ้ายกับปุ่ม Join ด้านขวาเหมือนกัน) ทุก Text เลยต้องกันล้นไว้ด้วย
class _RoomInfoColumn extends StatelessWidget {
  final PartyRoomModel room;
  const _RoomInfoColumn({required this.room});

  @override
  Widget build(BuildContext context) {
    final joinedLabel = room.capacity > 0
        ? '${room.memberCount} / ${room.capacity} joined'
        : '${room.memberCount} joined';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(Icons.calendar_today, formatEventDateTime(room.eventDate)),
        const SizedBox(height: 2),
        if (room.location.isNotEmpty) ...[
          _line(Icons.place_outlined, room.location),
          const SizedBox(height: 2),
        ],
        _line(Icons.groups, joinedLabel),
      ],
    );
  }

  Widget _line(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 10, color: Colors.grey),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// รูปปกเควสของห้อง — ใช้ path เดียวกับ _QuestThumbnail ใน quest_card.dart
class _RoomThumbnail extends StatelessWidget {
  final String? imageAsset;
  const _RoomThumbnail({required this.imageAsset});

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.image_outlined, color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageAsset == null) return _placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        imageAsset!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      ),
    );
  }
}
