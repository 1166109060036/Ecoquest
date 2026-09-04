// Model สำหรับข้อมูลที่แสดงในหน้า Profile
// ตอนนี้ยังไม่ได้ต่อ API จริง ใช้เป็นโครงไว้ก่อน เดี๋ยวมาต่อ backend endpoint ทีหลัง

class ProfileStats {
  final int questCompleted;
  final int questTotal;
  final double co2SavedKg;
  final int partiesJoined;

  ProfileStats({
    required this.questCompleted,
    required this.questTotal,
    required this.co2SavedKg,
    required this.partiesJoined,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      questCompleted: json['questCompleted'] ?? 0,
      questTotal: json['questTotal'] ?? 0,
      co2SavedKg: (json['co2SavedKg'] ?? 0).toDouble(),
      partiesJoined: json['partiesJoined'] ?? 0,
    );
  }
}

class AbilityUpgrade {
  final String id;
  final String title;
  final String description;
  final int cost; // ราคาเป็น Points
  final String iconKey; // ใช้ map ไปหา icon ใน UI

  AbilityUpgrade({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.iconKey,
  });

  factory AbilityUpgrade.fromJson(Map<String, dynamic> json) {
    return AbilityUpgrade(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      cost: json['cost'],
      iconKey: json['iconKey'] ?? 'star',
    );
  }
}
