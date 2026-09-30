import '../utils/quest_image.dart';

// การ์ด Eco Bingo รายสัปดาห์ — ข้อมูลจาก GET /api/bingo (backend/utils/bingo.js)
// 3x3 ช่องกลางฟรี / ช่องติดเมื่อเควสนั้นได้รางวัลแล้วในสัปดาห์นี้ / ครบแถวได้โบนัสเอง ไม่ต้องกดรับ
class BingoCell {
  final int index;
  final bool free;
  final String? questId;
  final String title;
  final String? imageKey;
  final bool done;
  // ส่งหลักฐานแล้ว รอตรวจอยู่
  final bool pending;

  BingoCell({
    required this.index,
    required this.free,
    this.questId,
    this.title = '',
    this.imageKey,
    this.done = false,
    this.pending = false,
  });

  String? get coverImageAsset => questCoverAsset(imageKey);

  factory BingoCell.fromJson(Map<String, dynamic> json) => BingoCell(
        index: json['index'] ?? 0,
        free: json['free'] == true,
        questId: json['questId']?.toString(),
        title: json['title'] ?? '',
        imageKey: json['imageKey'],
        done: json['done'] == true,
        pending: json['pending'] == true,
      );
}

class BingoCardModel {
  final String weekKey;
  final DateTime weekEndsAt;
  final List<BingoCell> cells;
  final List<List<int>> lines;
  final Set<int> completeLines;
  final int doneCount;
  final int questCount;
  final bool full;
  final int linePoints;
  final int lineXp;
  final int fullPoints;
  final int fullXp;

  BingoCardModel({
    required this.weekKey,
    required this.weekEndsAt,
    required this.cells,
    required this.lines,
    required this.completeLines,
    required this.doneCount,
    required this.questCount,
    required this.full,
    required this.linePoints,
    required this.lineXp,
    required this.fullPoints,
    required this.fullXp,
  });

  // ช่องที่อยู่ในแถวที่ครบแล้ว — ไฮไลต์บนการ์ด
  Set<int> get cellsInCompleteLines => {for (final l in completeLines) ...lines[l]};

  // ช่องที่ขาดอีกช่องเดียวก็ครบแถว — "one more for a line!"
  Set<int> get almostCells {
    final result = <int>{};
    for (var i = 0; i < lines.length; i++) {
      if (completeLines.contains(i)) continue;
      final missing = lines[i].where((c) => !cells[c].done).toList();
      if (missing.length == 1) result.add(missing.first);
    }
    return result;
  }

  factory BingoCardModel.fromJson(Map<String, dynamic> json) {
    final lineReward = (json['lineReward'] ?? {}) as Map<String, dynamic>;
    final fullReward = (json['fullReward'] ?? {}) as Map<String, dynamic>;
    return BingoCardModel(
      weekKey: json['weekKey'] ?? '',
      weekEndsAt: DateTime.tryParse(json['weekEndsAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      cells: ((json['cells'] ?? []) as List).map((c) => BingoCell.fromJson(c as Map<String, dynamic>)).toList(),
      lines: ((json['lines'] ?? []) as List).map((l) => (l as List).map((i) => i as int).toList()).toList(),
      completeLines: ((json['completeLines'] ?? []) as List).map((i) => i as int).toSet(),
      doneCount: json['doneCount'] ?? 0,
      questCount: json['questCount'] ?? 0,
      full: json['full'] == true,
      linePoints: lineReward['points'] ?? 0,
      lineXp: lineReward['xp'] ?? 0,
      fullPoints: fullReward['points'] ?? 0,
      fullXp: fullReward['xp'] ?? 0,
    );
  }
}
