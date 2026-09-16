// เพื่อน = ความสัมพันธ์ 2 คนที่ accepted แล้ว ข้อมูลจริงจาก GET /api/friends
// (ผลค้นหาจาก GET /api/friends/search และคำขอจาก GET /api/friends/requests ก็ใช้โครงเดียวกันนี้)
import '../utils/constants.dart';

class FriendModel {
  final String id;
  final String displayName;
  final String? avatarUrl; // null = ยังไม่ได้ตั้งรูปโปรไฟล์ (โชว์ไอคอนคนแทน)
  final int level;
  final String rank;

  FriendModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.rank,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: (json['id'] ?? '').toString(),
      displayName: json['displayName'] ?? 'Player',
      avatarUrl: AppConstants.resolveUrl(json['avatarUrl']),
      level: json['level'] ?? 1,
      rank: json['rank'] ?? 'Bronze',
    );
  }
}

// ผลค้นหา 1 แถว — เหมือน FriendModel เป๊ะๆ แต่แนบสถานะความสัมพันธ์กับเราไปด้วย ให้ UI โชว์ปุ่มถูกต้อง
// (ปุ่ม Add / รอตอบรับ / เป็นเพื่อนกันแล้ว) โดยไม่ต้องเทียบกับลิสต์เพื่อน/คำขอเองฝั่งแอพ
enum FriendRelationship { none, pendingOutgoing, pendingIncoming, friends }

FriendRelationship _relationshipFromJson(String? value) {
  switch (value) {
    case 'pending_outgoing':
      return FriendRelationship.pendingOutgoing;
    case 'pending_incoming':
      return FriendRelationship.pendingIncoming;
    case 'friends':
      return FriendRelationship.friends;
    default:
      return FriendRelationship.none;
  }
}

class FriendSearchResultModel {
  final FriendModel user;
  final FriendRelationship relationship;

  FriendSearchResultModel({required this.user, required this.relationship});

  factory FriendSearchResultModel.fromJson(Map<String, dynamic> json) {
    return FriendSearchResultModel(
      user: FriendModel.fromJson(json),
      relationship: _relationshipFromJson(json['relationship']),
    );
  }
}

// คำขอเพื่อน 1 ใบ (เข้า/ออก) — ข้อมูลจริงจาก GET /api/friends/requests?direction=incoming|outgoing
class FriendRequestModel {
  final String id;
  final FriendModel user; // อีกฝ่าย (ไม่ใช่เรา) ไม่ว่าเราเป็นผู้ส่งหรือผู้รับ
  final DateTime createdAt;

  FriendRequestModel({required this.id, required this.user, required this.createdAt});

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: (json['id'] ?? '').toString(),
      user: FriendModel.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
