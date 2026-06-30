import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/group.dart';
import '../models/message.dart';

class ApiService {
  // Automatically detects platform and routes to appropriate local IP address
  static String get baseUrl => 'https://vasl-backend.onrender.com';


  /// Update or register user profile on the server
  static Future<UserModel> updateProfile({
    required String userId,
    required String username,
    required String avatarUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'username': username,
          'avatarUrl': avatarUrl,
        }),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to update profile.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Create a new code-based group
  static Future<GroupModel> createGroup({
    required String groupName,
    required String creatorId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': groupName,
          'creatorId': creatorId,
        }),
      );

      if (response.statusCode == 201) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to create group.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Join an existing group using its unique 6-digit alphanumeric code
  static Future<GroupModel> joinGroup({
    required String groupCode,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/join'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': groupCode,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to join group.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Fetch all groups a user is member of
  static Future<List<GroupModel>> getUserGroups(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/groups/user/$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => GroupModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch user groups.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Fetch group members list and full details
  static Future<GroupModel> getGroupDetails(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/groups/$groupId/details'),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load group details.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Fetch previous messages in a group
  static Future<List<MessageModel>> getGroupMessages(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/groups/$groupId/messages'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MessageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Update group profile picture (avatar) on the server
  static Future<GroupModel> updateGroupAvatar({
    required String groupId,
    required String avatarUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/avatar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'avatarUrl': avatarUrl,
        }),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to update group icon.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Promote a member to sub-creator (admin)
  static Future<GroupModel> promoteUser(String groupId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/promote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to promote user.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Demote a sub-creator (admin) back to regular member
  static Future<GroupModel> demoteUser(String groupId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/demote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to demote user.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Kick/remove a user from the group
  static Future<GroupModel> kickUser(String groupId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/kick'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to remove user.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Lock/unlock group chat sending permissions
  static Future<GroupModel> lockGroup(String groupId, bool isLocked) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/lock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'isLocked': isLocked}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to update lock settings.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Set group privacy (public/private)
  static Future<GroupModel> setPrivacy(String groupId, String privacy) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/privacy'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'privacy': privacy}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to update privacy settings.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Approve a user's join request
  static Future<GroupModel> acceptRequest(String groupId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/requests/accept'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to approve join request.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Reject/decline a user's join request
  static Future<GroupModel> rejectRequest(String groupId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/$groupId/requests/reject'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return GroupModel.fromJson(json.decode(response.body));
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to decline request.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Delete a group permanently
  static Future<bool> deleteGroup(String groupId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/groups/$groupId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final err = json.decode(response.body);
        throw Exception(err['message'] ?? 'Failed to delete group.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
