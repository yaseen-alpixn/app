import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';
import 'group_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Load message history and fetch member list details
      chatProvider.loadMessageHistory(widget.groupId, auth.currentUser!.userId);
      chatProvider.loadGroupDetails(widget.groupId);
      
      _scrollToBottom(delayMs: 200);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({int delayMs = 100}) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Triggers message sending via provider (instigates Optimistic rendering)
  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    _messageController.clear();
    
    chatProvider.sendMessage(
      widget.groupId,
      auth.currentUser!.userId,
      auth.currentUser!.username,
      text,
    );

    _scrollToBottom();
  }

  /// Displays a sleek pop-up dialog showing user profile name and profile image
  void _showUserProfileDialog(BuildContext context, String userId, String username) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final details = chatProvider.getDetails(widget.groupId);
    
    // Attempt to resolve avatarUrl from resolved members in the provider cache
    String avatarUrl = '';
    if (details != null) {
      final memberIndex = details.resolvedMembers.indexWhere((m) => m.userId == userId);
      if (memberIndex != -1) {
        avatarUrl = details.resolvedMembers[memberIndex].avatarUrl;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: AppTheme.selfBubbleColor,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 54, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  username,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'User ID: ${userId.substring(0, 8)}...',
                  style: TextStyle(
                    color: AppTheme.textLightColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isUploadingFile = false;

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: AppTheme.primaryColor),
                title: const Text('Send Image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: AppTheme.primaryColor),
                title: const Text('Send Document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendMedia(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingFile = true;
      });

      final File file = File(pickedFile.path);
      final uploadedUrl = await CloudinaryService.uploadFile(file);

      setState(() {
        _isUploadingFile = false;
      });

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.sendMessage(
        widget.groupId,
        auth.currentUser!.userId,
        auth.currentUser!.username,
        '',
        type: 'image',
        fileUrl: uploadedUrl,
        fileName: pickedFile.name,
      );
    } catch (e) {
      setState(() {
        _isUploadingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isUploadingFile = true;
      });

      final File file = File(result.files.single.path!);
      final uploadedUrl = await CloudinaryService.uploadFile(file);

      setState(() {
        _isUploadingFile = false;
      });

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await chatProvider.sendMessage(
        widget.groupId,
        auth.currentUser!.userId,
        auth.currentUser!.username,
        '',
        type: 'file',
        fileUrl: uploadedUrl,
        fileName: result.files.single.name,
      );
    } catch (e) {
      setState(() {
        _isUploadingFile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload file: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching url: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final messages = chatProvider.getMessages(widget.groupId);
    final isHistoryLoading = chatProvider.isMessagesLoading(widget.groupId);

    // Auto-scroll on new message append
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      // Header Navigation: Tapping anywhere on the AppBar body directs to GroupDetailsScreen
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(groupId: widget.groupId),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.selfBubbleColor,
                backgroundImage: (chatProvider.getDetails(widget.groupId)?.avatarUrl.isNotEmpty == true)
                    ? NetworkImage(chatProvider.getDetails(widget.groupId)!.avatarUrl)
                    : null,
                child: (chatProvider.getDetails(widget.groupId) == null || chatProvider.getDetails(widget.groupId)!.avatarUrl.isEmpty)
                    ? Text(
                        widget.groupName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text(
                      'Tap here for group info',
                      style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),

        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat bubble stream
            Expanded(
              child: isHistoryLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? _buildEmptyChatState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isSelf = message.senderId == auth.currentUser?.userId;
                            return _buildMessageBubble(message, isSelf);
                          },
                        ),
            ),

            if (_isUploadingFile)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.grey.shade50,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Uploading attachment...',
                      style: TextStyle(color: AppTheme.textLightColor, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // Keyboard-resilient input view wrapping (Scaffold manages bottom insets dynamically)
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No Messages yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Send a message to start the conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isSelf) {
    final timeText = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0, top: 4.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelf ? AppTheme.selfBubbleColor : AppTheme.otherBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isSelf ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isSelf ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender display name (only show on peer messages)
            if (!isSelf)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: GestureDetector(
                  onTap: () => _showUserProfileDialog(context, message.senderId, message.senderName),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            
            // Message media/text content rendering
            if (message.type == 'image') ...[
              GestureDetector(
                onTap: () => _launchURL(message.fileUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    message.fileUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 150,
                        width: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        width: 200,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: AppTheme.textDarkColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ] else if (message.type == 'file') ...[
              InkWell(
                onTap: () => _launchURL(message.fileUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message.fileName.isNotEmpty ? message.fileName : 'Document',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textDarkColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.download, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              if (message.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: AppTheme.textDarkColor,
                    fontSize: 15,
                  ),
                ),
              ],
            ] else ...[
              Text(
                message.text,
                style: const TextStyle(
                  color: AppTheme.textDarkColor,
                  fontSize: 15,
                ),
              ),
            ],
            
            const SizedBox(height: 4),
            
            // Meta-status row (timestamp + delivery icon indicator)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: TextStyle(
                    color: AppTheme.textLightColor.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
                if (isSelf) ...[
                  const SizedBox(width: 4),
                  // Optimistic UI checks: Clock icon if delivering, checkmark when succeeded
                  Icon(
                    message.isSent ? Icons.done : Icons.access_time,
                    size: 12,
                    color: message.isSent ? AppTheme.primaryColor : Colors.grey,
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final group = chatProvider.getDetails(widget.groupId);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.userId ?? '';

    final bool isLocked = group?.isLocked ?? false;
    final bool isCreator = group?.createdBy == currentUserId;
    final bool isAdmin = group?.admins.contains(currentUserId) ?? false;
    final bool canPost = !isLocked || isCreator || isAdmin;

    if (!canPost) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        color: Colors.grey.shade100,
        child: const Text(
          'Only admins can send messages to this group.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textLightColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: AppTheme.primaryColor),
            onPressed: _isUploadingFile ? null : _showAttachmentMenu,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                fillColor: Colors.grey.shade100,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
