class UserModel {
  final String userId;
  final String username;
  final String avatarUrl;
  final String pushToken;

  UserModel({
    required this.userId,
    required this.username,
    this.avatarUrl = '',
    this.pushToken = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      pushToken: json['pushToken'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'pushToken': pushToken,
    };
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    String? pushToken,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      pushToken: pushToken ?? this.pushToken,
    );
  }
}
