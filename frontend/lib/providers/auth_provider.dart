import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  final SocketService _socketService;
  
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isRegistered => _currentUser != null && _currentUser!.username.isNotEmpty;

  AuthProvider(this._socketService) {
    _initLocalProfile();
  }

  /// Load cached user profile details or generate a new local UUID v4 identity
  Future<void> _initLocalProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');
      String? username = prefs.getString('username');
      String? avatarUrl = prefs.getString('avatarUrl') ?? '';

      if (userId == null || userId.isEmpty) {
        // Generate new local UUID v4
        userId = const Uuid().v4();
        await prefs.setString('userId', userId);
      }

      _currentUser = UserModel(
        userId: userId,
        username: username ?? '',
        avatarUrl: avatarUrl,
      );

      // If user has set a username, establish socket connection and sync in background
      if (isRegistered) {
        _socketService.connect(_currentUser!.userId);
        
        // Sync profile to database in the background without blocking app startup
        ApiService.updateProfile(
          userId: _currentUser!.userId,
          username: _currentUser!.username,
          avatarUrl: _currentUser!.avatarUrl,
        ).then((updatedUser) async {
          _currentUser = updatedUser;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', updatedUser.username);
          await prefs.setString('avatarUrl', updatedUser.avatarUrl);
          notifyListeners();
        }).catchError((err) {
          debugPrint('Background startup profile sync failed (offline): $err');
        });
      }
    } catch (e) {
      _errorMessage = 'Failed to load local profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Syncs profile details (name & avatar) to MongoDB and triggers socket connection
  Future<bool> syncProfileWithServer(String username, String avatarUrl) async {
    if (_currentUser == null) return false;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validate inputs
      final sanitizedName = username.trim();
      if (sanitizedName.isEmpty) {
        throw Exception('Profile name cannot be blank.');
      }
      if (sanitizedName.length > 25) {
        throw Exception('Profile name cannot exceed 25 characters.');
      }

      // 1. Save to backend database
      final updatedUser = await ApiService.updateProfile(
        userId: _currentUser!.userId,
        username: sanitizedName,
        avatarUrl: avatarUrl,
      );

      // 2. Cache in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', updatedUser.username);
      await prefs.setString('avatarUrl', updatedUser.avatarUrl);

      // 3. Update memory state
      _currentUser = updatedUser;

      // 4. Establish persistent WebSockets
      _socketService.connect(_currentUser!.userId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear local profile for testing/resetting purposes
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('avatarUrl');
    _socketService.disconnect();
    await _initLocalProfile();
  }
}
