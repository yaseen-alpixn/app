import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/message.dart';
import 'api_service.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _currentUserId;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  io.Socket? get socket => _socket;

  // Stream for incoming messages across all joined rooms
  final StreamController<MessageModel> _messageStreamController =
      StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get messageStream => _messageStreamController.stream;

  /// Connects to the Socket.io server and registers the user
  void connect(String userId) {
    if (_socket != null && _socket!.connected) {
      if (_currentUserId == userId) return; // Already connected with this user
      disconnect();
    }

    _currentUserId = userId;
    _isConnecting = true;
    notifyListeners();

    // Configure client to connect with auto-reconnection and exponential backoff
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setReconnectionAttempts(999) // Infinite retry
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _isConnecting = false;
      debugPrint('Socket connected to backend.');
      notifyListeners();

      // Automatically register the user identity upon socket connection
      _socket!.emit('register_user', {'userId': userId});
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint('Socket disconnected from backend.');
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint('Socket connection error: $err');
      notifyListeners();
    });

    _socket!.onConnecting((_) {
      _isConnecting = true;
      notifyListeners();
    });

    // Handle real-time incoming messages
    _socket!.on('receive_message', (data) {
      try {
        final message = MessageModel.fromJson(data);
        _messageStreamController.add(message);
      } catch (e) {
        debugPrint('Error parsing received socket message: $e');
      }
    });
  }

  /// Join a group room on the socket backend
  void joinRoom(String groupId, String userId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_room', {
        'groupId': groupId,
        'userId': userId,
      });
      debugPrint('Socket Emitted join_room for: $groupId');
    }
  }

  /// Sends a message and triggers the callback when the server acknowledges
  void sendMessage(MessageModel message, Function(bool success, MessageModel? ackMsg) ackCallback) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Cannot send message: Socket is not connected.');
      ackCallback(false, null);
      return;
    }

    _socket!.emitWithAck('send_message', message.toJson(), ack: (response) {
      if (response != null && response['success'] == true) {
        try {
          final ackMessage = MessageModel.fromJson(response['message']);
          ackCallback(true, ackMessage);
        } catch (e) {
          debugPrint('Failed to parse message acknowledgment: $e');
          ackCallback(true, message.copyWith(isSent: true)); // Fallback success
        }
      } else {
        debugPrint('Socket send_message rejected by backend: ${response?['error']}');
        ackCallback(false, null);
      }
    });
  }

  /// Close socket connection and clean up resources
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _isConnecting = false;
    _currentUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageStreamController.close();
    super.dispose();
  }
}
