import 'package:flutter/material.dart';
import '../models/org_event_model.dart';
import '../utils/date_format.dart';
import 'pressable_scale.dart';

// การ์ดอีเวนต์องค์กรในลิสต์ Explore (chip "Event" และ "All") — โทน/ขนาดเดียวกับ PartyRoomCard ที่โชว์ปนกัน
class OrgEventCard extends StatelessWidget {
  final OrgEventModel event;
  final VoidCallback onTap;

  const OrgEventCard({super.key, required this.event, required this.onTap});

  String get _statusLabel {
    if (event.isMine) return 'Your event';
    if (event.hasAttended) return 'Checked in';
    if (event.isRegistered) return 'Joined';
    if (event.isFull) return 'Full';
    return 'View';
  }

  @override
  Widget build(BuildContext context) {
    final joined = event.isRegistered || event.hasAttended;
    return PressableScale(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: joined ? Colors.green.shade200 : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateTile(date: event.startAt, live: event.phase == 'live'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${event.points.toString().padLeft(3, '0')} P',
                                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(10)),
                                child: const Text(
                                  'Event',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.apartment_rounded, size: 11, color: Colors.indigo.shade300),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              event.org?.name ?? 'Organization',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _line(Icons.schedule,
                                    '${formatEventDateTime(event.startAt)}${event.phase == 'live' ? '  ·  now' : ''}'),
                                const SizedBox(height: 2),
                                _line(Icons.place_outlined, event.location),
                                const SizedBox(height: 2),
                                _line(Icons.groups, '${event.joinedCount} / ${event.capacity} joined'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: joined || event.isMine ? Colors.green.shade50 : Colors.green,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: joined || event.isMine ? Colors.green.shade700 : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

// ป้ายวันที่แทนรูปปก (อีเวนต์องค์กรไม่มีรูปเควส) — กำลังจัดอยู่ = พื้นเขียว
class _DateTile extends StatelessWidget {
  final DateTime date;
  final bool live;
  const _DateTile({required this.date, required this.live});

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  @override
  Widget build(BuildContext context) {
    final fg = live ? Colors.white : Colors.indigo;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: live ? Colors.green : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(live ? 'LIVE' : _months[date.month - 1],
              style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          Text('${date.day}', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.bold, height: 1.1)),
        ],
      ),
    );
  }
}
