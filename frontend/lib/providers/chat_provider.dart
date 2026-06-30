import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider extends ChangeNotifier {
  final SocketService _socketService;
  
  List<GroupModel> _groups = [];
  final Map<String, List<MessageModel>> _groupMessages = {};
  final Map<String, GroupModel> _groupDetails = {};
  
  bool _isLoadingGroups = false;
  final Map<String, bool> _isLoadingMessages = {};
  final Map<String, bool> _isLoadingDetails = {};
  
  String? _errorMessage;
  String? _currentUserId;
  StreamSubscription<MessageModel>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _groupDeletedSubscription;
  StreamSubscription<Map<String, dynamic>>? _userKickedSubscription;
  StreamSubscription<Map<String, dynamic>>? _requestAcceptedSubscription;
  StreamSubscription<Map<String, dynamic>>? _settingsUpdatedSubscription;

  List<GroupModel> get groups => _groups;
  bool get isLoadingGroups => _isLoadingGroups;
  String? get errorMessage => _errorMessage;

  ChatProvider(this._socketService) {
    // Listen for real-time messages received via Socket.io
    _messageSubscription = _socketService.messageStream.listen(_handleIncomingMessage);
    
    // Subscribe to group settings and member event streams
    _groupDeletedSubscription = _socketService.groupDeletedStream.listen(_handleGroupDeleted);
    _userKickedSubscription = _socketService.userKickedStream.listen(_handleUserKicked);
    _requestAcceptedSubscription = _socketService.requestAcceptedStream.listen(_handleRequestAccepted);
    _settingsUpdatedSubscription = _socketService.settingsUpdatedStream.listen(_handleSettingsUpdated);
  }

  List<MessageModel> getMessages(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  GroupModel? getDetails(String groupId) {
    return _groupDetails[groupId];
  }

  bool isMessagesLoading(String groupId) => _isLoadingMessages[groupId] ?? false;
  bool isDetailsLoading(String groupId) => _isLoadingDetails[groupId] ?? false;

  /// Loads all groups the user is currently a member of
  Future<void> loadGroups(String userId) async {
    _currentUserId = userId;
    _isLoadingGroups = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedGroups = await ApiService.getUserGroups(userId);
      _groups = fetchedGroups;
      
      // Auto-join socket rooms for all retrieved groups
      for (var group in _groups) {
        _socketService.joinRoom(group.id, userId);
      }
    } catch (e) {
      _errorMessage = 'Failed to load chats: $e';
    } finally {
      _isLoadingGroups = false;
      notifyListeners();
    }
  }

  /// Create a new code-based group and join it
  Future<GroupModel?> createGroup(String groupName, String creatorId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final newGroup = await ApiService.createGroup(groupName: groupName, creatorId: creatorId);
      _groups.insert(0, newGroup);
      
      // Subscribe to socket room
      _socketService.joinRoom(newGroup.id, creatorId);
      
      notifyListeners();
      return newGroup;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Join a group using the 6-digit invite code
  Future<GroupModel?> joinGroup(String groupCode, String userId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final joinedGroup = await ApiService.joinGroup(groupCode: groupCode, userId: userId);
      
      // Check if already in groups list to avoid duplicate rendering
      final index = _groups.indexWhere((g) => g.id == joinedGroup.id);
      if (index == -1) {
        _groups.insert(0, joinedGroup);
      } else {
        _groups[index] = joinedGroup;
      }

      // Subscribe to socket room
      _socketService.joinRoom(joinedGroup.id, userId);

      notifyListeners();
      return joinedGroup;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Fetch resolved group members & invite code details
  Future<void> loadGroupDetails(String groupId) async {
    _isLoadingDetails[groupId] = true;
    notifyListeners();

    try {
      final details = await ApiService.getGroupDetails(groupId);
      _groupDetails[groupId] = details;
    } catch (e) {
      debugPrint('Failed to load group details: $e');
    } finally {
      _isLoadingDetails[groupId] = false;
      notifyListeners();
    }
  }

  /// Load message history for a specific group
  Future<void> loadMessageHistory(String groupId, String userId) async {
    // Also ensure room is joined
    _socketService.joinRoom(groupId, userId);

    if (_groupMessages.containsKey(groupId) && _groupMessages[groupId]!.isNotEmpty) {
      // Don't show loading spinner if we already have cache
      _fetchMessageHistoryInBackground(groupId);
      return;
    }

    _isLoadingMessages[groupId] = true;
    notifyListeners();

    try {
      final messages = await ApiService.getGroupMessages(groupId);
      _groupMessages[groupId] = messages;
    } catch (e) {
      debugPrint('Error fetching message history: $e');
    } finally {
      _isLoadingMessages[groupId] = false;
      notifyListeners();
    }
  }

  Future<void> _fetchMessageHistoryInBackground(String groupId) async {
    try {
      final messages = await ApiService.getGroupMessages(groupId);
      _groupMessages[groupId] = messages;
      notifyListeners();
    } catch (e) {
      debugPrint('Background message fetch failed: $e');
    }
  }

  /// Sends a group message utilizing the Optimistic UI pattern
  Future<void> sendMessage(
    String groupId,
    String senderId,
    String senderName,
    String text, {
    String type = 'text',
    String fileUrl = '',
    String fileName = '',
  }) async {
    final messageId = const Uuid().v4();
    final tempMessage = MessageModel(
      messageId: messageId,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
      timestamp: DateTime.now(),
      isSent: false, // Optimistic UI: Clock/sending status icon active
    );

    // 1. Instantly append message to local UI state
    if (!_groupMessages.containsKey(groupId)) {
      _groupMessages[groupId] = [];
    }
    _groupMessages[groupId]!.add(tempMessage);
    
    // Sort just in case
    _groupMessages[groupId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();

    // 2. Transmit to backend via Socket.io
    _socketService.sendMessage(tempMessage, (success, ackMsg) {
      final list = _groupMessages[groupId];
      if (list == null) return;

      final index = list.indexWhere((m) => m.messageId == messageId);
      if (index != -1) {
        if (success && ackMsg != null) {
          // 3a. Update bubble state: mark isSent = true and synchronize server timestamp
          list[index] = ackMsg.copyWith(isSent: true);
        } else {
          // 3b. Mark it as failed (keeps it in list with clock indicator, or we can handle retry)
          // For simplicity, we just keep it as is (unsent) and flag it
          list[index] = list[index].copyWith(isSent: false);
        }
        notifyListeners();
      }
    });
  }

  /// Listener for real-time incoming broadcasts from Socket.io
  void _handleIncomingMessage(MessageModel message) {
    final groupId = message.groupId;
    
    if (!_groupMessages.containsKey(groupId)) {
      _groupMessages[groupId] = [];
    }

    final list = _groupMessages[groupId]!;
    final exists = list.any((m) => m.messageId == message.messageId);

    if (!exists) {
      list.add(message);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Update group sorting in chats hub to bring active group to top
      final groupIndex = _groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
        final group = _groups.removeAt(groupIndex);
        _groups.insert(0, group);
      }
      
      notifyListeners();
    }
  }

  /// Updates group profile photo on server and updates local state memory
  Future<bool> updateGroupPhoto(String groupId, String avatarUrl) async {
    try {
      final updatedGroup = await ApiService.updateGroupAvatar(
        groupId: groupId,
        avatarUrl: avatarUrl,
      );

      // Update in groups list
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = _groups[index].copyWith(avatarUrl: updatedGroup.avatarUrl);
      }

      // Update in details cache
      if (_groupDetails.containsKey(groupId)) {
        _groupDetails[groupId] = _groupDetails[groupId]!.copyWith(avatarUrl: updatedGroup.avatarUrl);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating group photo: $e');
      return false;
    }
  }

  void _handleGroupDeleted(Map<String, dynamic> data) {
    final String? groupId = data['groupId'];
    if (groupId != null) {
      _groups.removeWhere((g) => g.id == groupId);
      _groupMessages.remove(groupId);
      _groupDetails.remove(groupId);
      notifyListeners();
    }
  }

  void _handleUserKicked(Map<String, dynamic> data) {
    final String? groupId = data['groupId'];
    final String? userId = data['userId'];
    if (groupId != null && userId != null) {
      if (userId == _currentUserId) {
        _groups.removeWhere((g) => g.id == groupId);
        _groupMessages.remove(groupId);
        _groupDetails.remove(groupId);
        notifyListeners();
      } else {
        if (_groupDetails.containsKey(groupId)) {
          loadGroupDetails(groupId);
        }
      }
    }
  }

  void _handleRequestAccepted(Map<String, dynamic> data) {
    final String? groupId = data['groupId'];
    final String? userId = data['userId'];
    if (groupId != null && userId != null && userId == _currentUserId) {
      if (_currentUserId != null) {
        loadGroups(_currentUserId!);
      }
    }
  }

  void _handleSettingsUpdated(Map<String, dynamic> data) {
    final String? groupId = data['groupId'];
    final bool? isLocked = data['isLocked'];
    final String? privacy = data['privacy'];
    if (groupId != null) {
      if (_groupDetails.containsKey(groupId)) {
        final current = _groupDetails[groupId]!;
        _groupDetails[groupId] = current.copyWith(
          isLocked: isLocked ?? current.isLocked,
          privacy: privacy ?? current.privacy,
        );
      }
      
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index != -1) {
        _groups[index] = _groups[index].copyWith(
          isLocked: isLocked ?? _groups[index].isLocked,
          privacy: privacy ?? _groups[index].privacy,
        );
      }
      notifyListeners();
    }
  }

  /// Promotes a member to admin
  Future<bool> promoteMember(String groupId, String userId) async {
    try {
      final updatedGroup = await ApiService.promoteUser(groupId, userId);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error promoting member: $e');
      return false;
    }
  }

  /// Demotes an admin back to member
  Future<bool> demoteAdmin(String groupId, String userId) async {
    try {
      final updatedGroup = await ApiService.demoteUser(groupId, userId);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error demoting admin: $e');
      return false;
    }
  }

  /// Kicks a member out of the group
  Future<bool> kickMember(String groupId, String userId) async {
    try {
      final updatedGroup = await ApiService.kickUser(groupId, userId);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error kicking member: $e');
      return false;
    }
  }

  /// Toggles locked status
  Future<bool> toggleLockGroup(String groupId, bool isLocked) async {
    try {
      final updatedGroup = await ApiService.lockGroup(groupId, isLocked);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error toggling lock settings: $e');
      return false;
    }
  }

  /// Updates group privacy (public/private)
  Future<bool> updateGroupPrivacy(String groupId, String privacy) async {
    try {
      final updatedGroup = await ApiService.setPrivacy(groupId, privacy);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error updating group privacy: $e');
      return false;
    }
  }

  /// Approves pending join request
  Future<bool> approveJoinRequest(String groupId, String userId) async {
    try {
      final updatedGroup = await ApiService.acceptRequest(groupId, userId);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error approving request: $e');
      return false;
    }
  }

  /// Declines pending join request
  Future<bool> declineJoinRequest(String groupId, String userId) async {
    try {
      final updatedGroup = await ApiService.rejectRequest(groupId, userId);
      _updateDetailsCache(groupId, updatedGroup);
      return true;
    } catch (e) {
      debugPrint('Error declining request: $e');
      return false;
    }
  }

  /// Deletes a group permanently
  Future<bool> deleteGroupPermanently(String groupId) async {
    try {
      final success = await ApiService.deleteGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        _groupMessages.remove(groupId);
        _groupDetails.remove(groupId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting group: $e');
      return false;
    }
  }

  void _updateDetailsCache(String groupId, GroupModel updatedGroup) {
    _groupDetails[groupId] = updatedGroup;
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      _groups[index] = _groups[index].copyWith(
        admins: updatedGroup.admins,
        isLocked: updatedGroup.isLocked,
        privacy: updatedGroup.privacy,
        members: updatedGroup.members,
        resolvedMembers: updatedGroup.resolvedMembers,
        requests: updatedGroup.requests,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _groupDeletedSubscription?.cancel();
    _userKickedSubscription?.cancel();
    _requestAcceptedSubscription?.cancel();
    _settingsUpdatedSubscription?.cancel();
    super.dispose();
  }
}
