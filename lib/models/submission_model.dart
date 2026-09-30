import '../utils/constants.dart';
import 'friend_model.dart';

// หลักฐานการทำภารกิจ 1 ครั้ง (รูปถ่าย) — ระบบตรวจสอบภารกิจ (28 ก.ย. 2026) ดู backend/utils/submissions.js
// ใช้ร่วมกัน 3 ที่: คิวตรวจ (ReviewPage), "Waiting for review" ในหน้า Progress, และฟีดชุมชน (FeedTab)
class SubmissionModel {
  final String id;
  final String kind; // quest / check_in / party
  final String status; // pending / approved / rejected
  final String photoUrl; // URL เต็มแล้ว (resolveUrl)
  final DateTime submittedAt;
  final int approvals;
  final int rejections;
  final int approvalsNeeded;
  // ค้างเกิน 48 ชม. ไม่มีข้อสรุป — รอแอดมินตัดสินคนเดียว (ผู้เล่นทั่วไปโหวตต่อไม่ได้แล้ว)
  final bool escalated;
  final int rewardPoints;
  final int rewardXp;
  final SubmissionQuest? quest;
  // ผู้ส่ง — ไม่มีใน "หลักฐานของฉัน" (GET /submissions/mine ไม่ populate ผู้ใช้)
  final FriendModel? user;
  final int? checkInDay;
  final int? checkInTotal;
  final int cheers;
  final bool cheeredByMe;

  SubmissionModel({
    required this.id,
    required this.kind,
    required this.status,
    required this.photoUrl,
    required this.submittedAt,
    this.approvals = 0,
    this.rejections = 0,
    this.approvalsNeeded = 2,
    this.escalated = false,
    this.rewardPoints = 0,
    this.rewardXp = 0,
    this.quest,
    this.user,
    this.checkInDay,
    this.checkInTotal,
    this.cheers = 0,
    this.cheeredByMe = false,
  });

  bool get isParty => kind == 'party';
  bool get isCheckIn => kind == 'check_in' && checkInDay != null && checkInTotal != null;

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    final questJson = json['quest'] as Map<String, dynamic>?;
    final userJson = json['user'] as Map<String, dynamic>?;
    final checkIn = json['checkIn'] as Map<String, dynamic>?;
    final reward = (json['reward'] ?? {}) as Map<String, dynamic>;
    return SubmissionModel(
      id: (json['id'] ?? '').toString(),
      kind: json['kind'] ?? 'quest',
      status: json['status'] ?? 'pending',
      photoUrl: AppConstants.resolveUrl(json['photoUrl']?.toString()) ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      approvals: json['approvals'] ?? 0,
      rejections: json['rejections'] ?? 0,
      approvalsNeeded: json['approvalsNeeded'] ?? 2,
      escalated: json['escalated'] == true,
      rewardPoints: reward['points'] ?? 0,
      rewardXp: reward['xp'] ?? 0,
      quest: questJson != null ? SubmissionQuest.fromJson(questJson) : null,
      user: userJson != null ? FriendModel.fromJson(userJson) : null,
      checkInDay: checkIn?['daysDone'],
      checkInTotal: checkIn?['durationDays'],
      cheers: json['cheers'] ?? 0,
      cheeredByMe: json['cheeredByMe'] ?? false,
    );
  }

  SubmissionModel copyWith({int? cheers, bool? cheeredByMe}) => SubmissionModel(
        id: id,
        kind: kind,
        status: status,
        photoUrl: photoUrl,
        submittedAt: submittedAt,
        approvals: approvals,
        rejections: rejections,
        approvalsNeeded: approvalsNeeded,
        escalated: escalated,
        rewardPoints: rewardPoints,
        rewardXp: rewardXp,
        quest: quest,
        user: user,
        checkInDay: checkInDay,
        checkInTotal: checkInTotal,
        cheers: cheers ?? this.cheers,
        cheeredByMe: cheeredByMe ?? this.cheeredByMe,
      );
}

class SubmissionQuest {
  final String id;
  final String title;
  final String detail;
  final String category;
  final double? co2eEstimateKg;
  final int durationDays;

  SubmissionQuest({
    required this.id,
    required this.title,
    this.detail = '',
    this.category = '',
    this.co2eEstimateKg,
    this.durationDays = 1,
  });

  factory SubmissionQuest.fromJson(Map<String, dynamic> json) => SubmissionQuest(
        id: (json['id'] ?? '').toString(),
        title: json['title'] ?? '',
        detail: json['detail'] ?? '',
        category: json['category'] ?? '',
        co2eEstimateKg: (json['co2eEstimateKg'] as num?)?.toDouble(),
        durationDays: json['durationDays'] ?? 1,
      );

  // CO2 ต่อการส่ง 1 ครั้ง — เควสหลายวันเป็นค่ารวมทุกวัน หารด้วยจำนวนวัน (แบบเดียวกับ backend/utils/profilePayload.js)
  double? get co2PerSubmission =>
      co2eEstimateKg == null ? null : co2eEstimateKg! / (durationDays < 1 ? 1 : durationDays);
}

// ผลจาก GET /api/reviews/queue
class ReviewQueue {
  final List<SubmissionModel> submissions;
  final int pendingCount;
  final bool isAdmin;
  // guest ตรวจไม่ได้ (บัญชีจริงเท่านั้น) — แอพชวนสมัครบัญชีแทนแบนเนอร์ตรวจ
  final bool canReview;
  // แอดมินเท่านั้น: จำนวนที่ค้างเกิน 48 ชม. รอแอดมินตัดสิน
  final int escalatedCount;

  ReviewQueue({
    required this.submissions,
    required this.pendingCount,
    required this.isAdmin,
    this.canReview = true,
    this.escalatedCount = 0,
  });
}
