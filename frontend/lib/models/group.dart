import 'user.dart';

class GroupModel {
  final String id;
  final String name;
  final String code;
  final List<String> members;
  final List<UserModel> resolvedMembers;
  final String createdBy;
  final String avatarUrl;
  final List<String> admins;
  final List<UserModel> requests;
  final bool isLocked;
  final String privacy;
  final DateTime? createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.code,
    this.members = const [],
    this.resolvedMembers = const [],
    required this.createdBy,
    this.avatarUrl = '',
    this.admins = const [],
    this.requests = const [],
    this.isLocked = false,
    this.privacy = 'public',
    this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    // Determine whether members is list of strings or list of JSON objects
    List<String> rawMembers = [];
    List<UserModel> resolved = [];

    if (json['members'] != null) {
      for (var item in json['members']) {
        if (item is String) {
          rawMembers.add(item);
        } else if (item is Map<String, dynamic>) {
          final user = UserModel.fromJson(item);
          resolved.add(user);
          rawMembers.add(user.userId);
        }
      }
    }

    List<UserModel> rawRequests = [];
    if (json['requests'] != null) {
      for (var item in json['requests']) {
        if (item is Map<String, dynamic>) {
          rawRequests.add(UserModel.fromJson(item));
        }
      }
    }

    List<String> rawAdmins = [];
    if (json['admins'] != null) {
      rawAdmins = List<String>.from(json['admins']);
    }

    return GroupModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      members: rawMembers,
      resolvedMembers: resolved,
      createdBy: json['createdBy'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      admins: rawAdmins,
      requests: rawRequests,
      isLocked: json['isLocked'] ?? false,
      privacy: json['privacy'] ?? 'public',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'code': code,
      'members': resolvedMembers.isNotEmpty
          ? resolvedMembers.map((e) => e.toJson()).toList()
          : members,
      'createdBy': createdBy,
      'avatarUrl': avatarUrl,
      'admins': admins,
      'requests': requests.map((e) => e.toJson()).toList(),
      'isLocked': isLocked,
      'privacy': privacy,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? code,
    List<String>? members,
    List<UserModel>? resolvedMembers,
    String? createdBy,
    String? avatarUrl,
    List<String>? admins,
    List<UserModel>? requests,
    bool? isLocked,
    String? privacy,
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      members: members ?? this.members,
      resolvedMembers: resolvedMembers ?? this.resolvedMembers,
      createdBy: createdBy ?? this.createdBy,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      admins: admins ?? this.admins,
      requests: requests ?? this.requests,
      isLocked: isLocked ?? this.isLocked,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
