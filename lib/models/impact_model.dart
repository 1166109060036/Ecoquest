// ผลกระทบรวมของผู้เล่นทั้งเมือง — GET /api/impact/summary (backend/routes/impact.js)
// การ์ด "Ebetsu's impact" บนสุดของแท็บ Feed ใน Community
class ImpactSummary {
  final ImpactPeriod allTime;
  final ImpactPeriod thisWeek;
  final String city;

  ImpactSummary({required this.allTime, required this.thisWeek, required this.city});

  factory ImpactSummary.fromJson(Map<String, dynamic> json) => ImpactSummary(
        allTime: ImpactPeriod.fromJson((json['allTime'] ?? {}) as Map<String, dynamic>),
        thisWeek: ImpactPeriod.fromJson((json['thisWeek'] ?? {}) as Map<String, dynamic>),
        city: json['city'] ?? 'Ebetsu',
      );
}

class ImpactPeriod {
  final double co2eKg;
  final int questsCompleted;
  final int players;
  // ต้นสน 1 ต้น (อายุ 36-40 ปี) ดูดซับ ~8.8 kgCO2/ปี — ที่มาดู backend/utils/impactEquivalents.js
  final double cedarTreeYears;
  final int cedarTreeDays;

  ImpactPeriod({
    required this.co2eKg,
    required this.questsCompleted,
    required this.players,
    required this.cedarTreeYears,
    required this.cedarTreeDays,
  });

  factory ImpactPeriod.fromJson(Map<String, dynamic> json) {
    final eq = (json['equivalents'] ?? {}) as Map<String, dynamic>;
    return ImpactPeriod(
      co2eKg: (json['co2eKg'] as num?)?.toDouble() ?? 0,
      questsCompleted: json['questsCompleted'] ?? 0,
      players: json['players'] ?? 0,
      cedarTreeYears: (eq['cedarTreeYears'] as num?)?.toDouble() ?? 0,
      cedarTreeDays: (eq['cedarTreeDays'] as num?)?.toInt() ?? 0,
    );
  }

  // ข้อความเทียบที่อ่านง่ายที่สุดตามขนาดยอด — ครบต้นละปีแล้วนับเป็นจำนวนต้น ยังไม่ถึงนับเป็นวันของต้นเดียว
  String get treeComparison {
    if (cedarTreeYears >= 1) {
      final trees = cedarTreeYears >= 10 ? cedarTreeYears.round().toString() : cedarTreeYears.toStringAsFixed(1);
      return 'what $trees cedar trees absorb in a year';
    }
    final days = cedarTreeDays < 1 ? 1 : cedarTreeDays;
    return 'what one cedar tree absorbs in $days day${days == 1 ? '' : 's'}';
  }
}
