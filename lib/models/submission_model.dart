import 'proof_form.dart';
import '../utils/constants.dart';
import 'friend_model.dart';

// หลักฐานการทำภารกิจ 1 ครั้ง (รูปถ่าย) — ดู backend/utils/submissions.js
// 7 ต.ค. 2026: ส่งรูปแล้วผ่านทันที (เลิกให้ผู้เล่นตรวจ) ผู้เล่นรายงานโพสต์ได้ / แอดมินดูเฉพาะที่ถูกรายงาน
// ใช้ร่วมกัน 2 ที่: ฟีดชุมชน (FeedTab) และโพสต์ที่ถูกรายงานของแอดมิน (ReportedPostsPage)
class SubmissionModel {
  final String id;
  final String kind; // quest / check_in / party
  final String status; // approved / rejected (pending = ของเก่าจากระบบให้คนตรวจ)
  final String photoUrl; // URL เต็มแล้ว (resolveUrl)
  final DateTime submittedAt;
  final int rewardPoints;
  final int rewardXp;
  final SubmissionQuest? quest;
  // ผู้ส่ง — ไม่มีใน "หลักฐานของฉัน" (GET /submissions/mine ไม่ populate ผู้ใช้)
  final FriendModel? user;
  final int? checkInDay;
  final int? checkInTotal;
  final int cheers;
  final bool cheeredByMe;
  // ฟีด: คนดูถอนโพสต์นี้ได้ไหม (แอดมิน = ทุกโพสต์ / เจ้าของ = ของตัวเอง) — backend/routes/feed.js
  final bool canRemove;
  // ฟีด: รายงานได้ไหม (บัญชีจริง + ไม่ใช่ของตัวเอง) / รายงานไปแล้ว
  final bool canReport;
  final bool reportedByMe;
  // ---- เฉพาะหน้าโพสต์ที่ถูกรายงานของแอดมิน (backend/routes/reviews.js) ----
  final int reportCount;
  final Map<String, int> reportReasons; // { not_done: 2, personal_info: 1 }
  final bool hiddenByReports; // รายงานครบเกณฑ์ ซ่อนจากฟีดอยู่
  final bool canRevoke; // ของเก่าก่อน 7 ต.ค. 2026 ยึดแต้มคืนไม่ได้
  // ข้อมูลที่กรอกตามฟอร์มของเควส (เช่น ส่งคืนอะไร/กี่ชิ้น/ร้านไหน) — null = ไม่มี
  final ProofDetails? details;

  SubmissionModel({
    required this.id,
    required this.kind,
    required this.status,
    required this.photoUrl,
    required this.submittedAt,
    this.rewardPoints = 0,
    this.rewardXp = 0,
    this.quest,
    this.user,
    this.checkInDay,
    this.checkInTotal,
    this.cheers = 0,
    this.cheeredByMe = false,
    this.canRemove = false,
    this.canReport = false,
    this.reportedByMe = false,
    this.reportCount = 0,
    this.reportReasons = const {},
    this.hiddenByReports = false,
    this.canRevoke = false,
    this.details,
  });

  bool get isParty => kind == 'party';
  bool get isCheckIn => kind == 'check_in' && checkInDay != null && checkInTotal != null;

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    final questJson = json['quest'] as Map<String, dynamic>?;
    final userJson = json['user'] as Map<String, dynamic>?;
    final checkIn = json['checkIn'] as Map<String, dynamic>?;
    final reward = (json['reward'] ?? {}) as Map<String, dynamic>;
    final reasons = json['reportReasons'];
    return SubmissionModel(
      id: (json['id'] ?? '').toString(),
      kind: json['kind'] ?? 'quest',
      status: json['status'] ?? 'approved',
      photoUrl: AppConstants.resolveUrl(json['photoUrl']?.toString()) ?? '',
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      rewardPoints: reward['points'] ?? 0,
      rewardXp: reward['xp'] ?? 0,
      quest: questJson != null ? SubmissionQuest.fromJson(questJson) : null,
      user: userJson != null ? FriendModel.fromJson(userJson) : null,
      checkInDay: checkIn?['daysDone'],
      checkInTotal: checkIn?['durationDays'],
      cheers: json['cheers'] ?? 0,
      cheeredByMe: json['cheeredByMe'] ?? false,
      canRemove: json['canRemove'] == true,
      canReport: json['canReport'] == true,
      reportedByMe: json['reportedByMe'] == true,
      reportCount: json['reportCount'] ?? 0,
      reportReasons: reasons is Map
          ? reasons.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : const {},
      hiddenByReports: json['hiddenByReports'] == true,
      canRevoke: json['canRevoke'] == true,
      details: json['details'] is Map<String, dynamic>
          ? ProofDetails.fromJson(json['details'] as Map<String, dynamic>)
          : null,
    );
  }

  SubmissionModel copyWith({int? cheers, bool? cheeredByMe, bool? reportedByMe}) => SubmissionModel(
        id: id,
        kind: kind,
        status: status,
        photoUrl: photoUrl,
        submittedAt: submittedAt,
        rewardPoints: rewardPoints,
        rewardXp: rewardXp,
        quest: quest,
        user: user,
        checkInDay: checkInDay,
        checkInTotal: checkInTotal,
        cheers: cheers ?? this.cheers,
        cheeredByMe: cheeredByMe ?? this.cheeredByMe,
        canRemove: canRemove,
        canReport: canReport,
        reportedByMe: reportedByMe ?? this.reportedByMe,
        reportCount: reportCount,
        reportReasons: reportReasons,
        hiddenByReports: hiddenByReports,
        canRevoke: canRevoke,
        details: details,
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

// ผลจาก GET /api/reviews/queue — โพสต์ที่ถูกรายงาน (แอดมินเท่านั้น ผู้เล่นทั่วไปได้ลิสต์ว่าง isAdmin: false)
class ReportQueue {
  final List<SubmissionModel> submissions;
  final int pendingCount; // จำนวนที่รอแอดมินดูทั้งหมด
  final bool isAdmin;

  ReportQueue({required this.submissions, required this.pendingCount, required this.isAdmin});
}

// เหตุผลที่รายงานได้ — ตรงกับ backend/utils/submissions.js REPORT_REASONS
const reportReasonLabels = <String, String>{
  'not_done': "Doesn't show the quest",
  'personal_info': 'Shows personal info',
  'inappropriate': 'Inappropriate photo',
  'other': 'Something else',
};
