// ฟอร์มเก็บข้อมูลเพิ่มตอนส่งรูปหลักฐาน — เควสที่ backend ตั้ง Quest.proofForm ไว้ (backend/utils/proofForm.js)
// เช่น "Return Containers to the Store": ส่งคืนอะไร (เลือกได้หลายอัน) / กี่ชิ้น / ร้านไหน (ไม่บังคับ)
class ProofForm {
  final String? choiceLabel;
  final List<String> choices; // ว่าง = ไม่ถาม
  final String? countLabel;
  final int? countMax; // null = ไม่ถามจำนวน
  final String? placeLabel; // null = ไม่ถามสถานที่

  const ProofForm({this.choiceLabel, this.choices = const [], this.countLabel, this.countMax, this.placeLabel});

  factory ProofForm.fromJson(Map<String, dynamic> json) => ProofForm(
        choiceLabel: json['choiceLabel'],
        choices: ((json['choices'] as List?) ?? const []).map((e) => e.toString()).toList(),
        countLabel: json['countLabel'],
        countMax: json['countMax'] is int ? json['countMax'] as int : null,
        placeLabel: json['placeLabel'],
      );

  bool get asksChoices => choices.isNotEmpty;
  bool get asksCount => countMax != null && countMax! > 0;
  bool get asksPlace => placeLabel != null && placeLabel!.isNotEmpty;
}

// คำตอบของฟอร์ม — ส่งไปเป็น proofDetails ตอน Complete / backend ส่งกลับมาใน submission.details
class ProofDetails {
  final List<String> choices;
  final int? count;
  final String? place;

  const ProofDetails({this.choices = const [], this.count, this.place});

  factory ProofDetails.fromJson(Map<String, dynamic> json) => ProofDetails(
        choices: ((json['choices'] as List?) ?? const []).map((e) => e.toString()).toList(),
        count: json['count'] is int ? json['count'] as int : null,
        place: json['place'],
      );

  Map<String, dynamic> toJson() => {
        if (choices.isNotEmpty) 'choices': choices,
        if (count != null) 'count': count,
        if (place != null && place!.trim().isNotEmpty) 'place': place!.trim(),
      };

  // บรรทัดสรุปให้ผู้ตรวจ/ฟีด เช่น "Food trays, Milk cartons · 6 items · at Coop"
  String get summary => [
        if (choices.isNotEmpty) choices.join(', '),
        if (count != null) '$count ${count == 1 ? 'item' : 'items'}',
        if (place != null && place!.isNotEmpty) 'at $place',
      ].join(' · ');
}
