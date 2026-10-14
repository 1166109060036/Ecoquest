import 'package:flutter/material.dart';
import '../utils/constants.dart';

// บัญชีองค์กร + อีเวนต์องค์กร (14 ต.ค. 2026) — ข้อมูลจาก backend/routes/org.js
// องค์กรสร้างอีเวนต์ -> ผู้เล่นลงทะเบียน -> มางานแล้วสแกน QR ที่องค์กรเปิด -> ได้แต้มทันที

// ประเภทองค์กร — key ตรงกับ ORG_TYPES ใน backend/models/User.js
const orgTypeLabels = {
  'npo': 'Non-profit / NPO',
  'company': 'Company',
  'school': 'School / University',
  'government': 'Local government',
  'community': 'Community group',
  'other': 'Other',
};

// หมวดอีเวนต์ = หมวดเควส (นับเข้าเหรียญของหมวดนั้น)
const orgEventCategoryLabels = {
  'community': 'Community',
  'recycling': 'Recycling',
  'plastic': 'Plastic',
  'food_waste': 'Food Waste',
  'energy': 'Energy',
};

IconData orgEventCategoryIcon(String category) => switch (category) {
      'recycling' => Icons.recycling,
      'plastic' => Icons.local_drink_outlined,
      'food_waste' => Icons.restaurant_outlined,
      'energy' => Icons.bolt_outlined,
      _ => Icons.volunteer_activism_outlined,
    };

// สถานะองค์กรของฉัน (GET /org/me) — none / pending / approved / rejected / suspended
class OrgProfile {
  final String status;
  final String name;
  final String orgType;
  final String description;
  final String contactEmail;
  final String decisionNote;

  const OrgProfile({
    this.status = 'none',
    this.name = '',
    this.orgType = '',
    this.description = '',
    this.contactEmail = '',
    this.decisionNote = '',
  });

  bool get isApproved => status == 'approved';

  factory OrgProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OrgProfile();
    return OrgProfile(
      status: json['status'] ?? 'none',
      name: json['name'] ?? '',
      orgType: json['orgType'] ?? '',
      description: json['description'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      decisionNote: json['decisionNote'] ?? '',
    );
  }
}

class OrgInfo {
  final String id;
  final String name;
  final String orgType;
  final String? avatarUrl;

  const OrgInfo({required this.id, required this.name, required this.orgType, this.avatarUrl});

  factory OrgInfo.fromJson(Map<String, dynamic> json) => OrgInfo(
        id: (json['id'] ?? '').toString(),
        name: json['name'] ?? 'Organization',
        orgType: json['orgType'] ?? '',
        avatarUrl: AppConstants.resolveUrl(json['avatarUrl']),
      );
}

class OrgEventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final int joinedCount; // ลงทะเบียน + เช็คอินแล้ว
  final int attendedCount;
  final int points;
  final int xp;
  // upcoming / live / ended / cancelled — backend คิดจากเวลาให้แล้ว
  final String phase;
  // สแกนเช็คอินได้ตอนนี้ไหม (ก่อนงานเริ่ม 30 นาที ถึงหลังงานจบ 30 นาที)
  final bool checkInOpen;
  final OrgInfo? org;
  final bool isMine; // ฉันเป็นองค์กรที่จัดงานนี้
  final String? myStatus; // null / registered / attended
  final int? myRewardPoints;

  const OrgEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.joinedCount,
    required this.attendedCount,
    required this.points,
    required this.xp,
    required this.phase,
    required this.checkInOpen,
    this.org,
    this.isMine = false,
    this.myStatus,
    this.myRewardPoints,
  });

  bool get isFull => joinedCount >= capacity;
  bool get isCancelled => phase == 'cancelled';
  bool get isEnded => phase == 'ended';
  bool get isRegistered => myStatus == 'registered';
  bool get hasAttended => myStatus == 'attended';
  bool get canCancelRegistration => isRegistered && phase == 'upcoming';

  String get phaseLabel => switch (phase) {
        'live' => 'Happening now',
        'ended' => 'Ended',
        'cancelled' => 'Cancelled',
        _ => 'Upcoming',
      };

  Color get phaseColor => switch (phase) {
        'live' => Colors.green,
        'ended' => Colors.grey,
        'cancelled' => Colors.redAccent,
        _ => Colors.blue,
      };

  factory OrgEventModel.fromJson(Map<String, dynamic> json) {
    final reward = json['myReward'] as Map<String, dynamic>?;
    return OrgEventModel(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'community',
      location: json['location'] ?? '',
      startAt: DateTime.tryParse(json['startAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      endAt: DateTime.tryParse(json['endAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      joinedCount: (json['joinedCount'] as num?)?.toInt() ?? 0,
      attendedCount: (json['attendedCount'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      phase: json['phase'] ?? 'upcoming',
      checkInOpen: json['checkInOpen'] == true,
      org: json['org'] is Map<String, dynamic> ? OrgInfo.fromJson(json['org'] as Map<String, dynamic>) : null,
      isMine: json['isMine'] == true,
      myStatus: json['myStatus'],
      myRewardPoints: (reward?['points'] as num?)?.toInt(),
    );
  }
}

class OrgAttendee {
  final String userId;
  final String displayName;
  final int level;
  final String? avatarUrl;
  final bool attended;
  final DateTime? attendedAt;

  const OrgAttendee({
    required this.userId,
    required this.displayName,
    required this.level,
    this.avatarUrl,
    required this.attended,
    this.attendedAt,
  });

  factory OrgAttendee.fromJson(Map<String, dynamic> json) => OrgAttendee(
        userId: (json['userId'] ?? '').toString(),
        displayName: json['displayName'] ?? 'Player',
        level: (json['level'] as num?)?.toInt() ?? 1,
        avatarUrl: AppConstants.resolveUrl(json['avatarUrl']),
        attended: json['status'] == 'attended',
        attendedAt: DateTime.tryParse(json['attendedAt']?.toString() ?? '')?.toLocal(),
      );
}

// คำขอเป็นองค์กร (หน้าแอดมิน)
class OrgRequest {
  final String userId;
  final String email;
  final String displayName;
  final OrgProfile organization;

  const OrgRequest({required this.userId, required this.email, required this.displayName, required this.organization});

  factory OrgRequest.fromJson(Map<String, dynamic> json) => OrgRequest(
        userId: (json['userId'] ?? '').toString(),
        email: json['email'] ?? '',
        displayName: json['displayName'] ?? '',
        organization: OrgProfile.fromJson(json['organization'] as Map<String, dynamic>?),
      );
}
