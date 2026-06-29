import 'user.dart';

class GroupModel {
  final String id;
  final String name;
  final String code;
  final List<String> members;
  final List<UserModel> resolvedMembers;
  final String createdBy;
  final DateTime? createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.code,
    this.members = const [],
    this.resolvedMembers = const [],
    required this.createdBy,
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

    return GroupModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      members: rawMembers,
      resolvedMembers: resolved,
      createdBy: json['createdBy'] ?? '',
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
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      members: members ?? this.members,
      resolvedMembers: resolvedMembers ?? this.resolvedMembers,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
