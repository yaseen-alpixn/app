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
}
