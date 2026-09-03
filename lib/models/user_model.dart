class UserModel {
  final String id;
  final String? email;
  final String displayName;
  final bool isGuest;

  UserModel({
    required this.id,
    this.email,
    required this.displayName,
    required this.isGuest,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'],
      email: json['email'],
      displayName: json['displayName'] ?? 'Player',
      isGuest: json['isGuest'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'isGuest': isGuest,
    };
  }
}
