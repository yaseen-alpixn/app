import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  bool _isUpdatingPhoto = false;

  /// Select profile image from device gallery and update group photo
  Future<void> _pickAndUploadGroupPhoto(GroupModel group) async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUpdatingPhoto = true;
      });

      final File file = File(pickedFile.path);
      final uploadedUrl = await CloudinaryService.uploadImage(file);

      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final success = await chatProvider.updateGroupPhoto(group.id, uploadedUrl);


      setState(() {
        _isUpdatingPhoto = false;
      });

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group icon updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save group icon on server.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUpdatingPhoto = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Load fresh details (member display names resolution) from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false)
          .loadGroupDetails(widget.groupId);
    });
  }

  /// Copies 6-digit invite code to OS Clipboard
  void _copyToClipboard(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied to clipboard!'),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Displays a sleek pop-up dialog showing user profile name and profile image
  void _showUserProfileDialog(BuildContext context, String userId, String username, String avatarUrl) {
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final group = chatProvider.getDetails(widget.groupId);
    final isLoading = chatProvider.isDetailsLoading(widget.groupId);
    final currentUserId = auth.currentUser?.userId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
      ),
      body: isLoading && group == null
          ? const Center(child: CircularProgressIndicator())
          : group == null
              ? const Center(child: Text('Failed to load group info.'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Large Header Section
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        child: Column(
                          children: [
                            // Large Group Avatar wrapper
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: AppTheme.selfBubbleColor,
                                  backgroundImage: group.avatarUrl.isNotEmpty
                                      ? NetworkImage(group.avatarUrl)
                                      : null,
                                  child: group.avatarUrl.isEmpty
                                      ? Text(
                                          group.name.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                if (_isUpdatingPhoto)
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    radius: 14,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                      onPressed: _isUpdatingPhoto ? null : () => _pickAndUploadGroupPhoto(group),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 24,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Code-Based Group Invite Code section
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invite Code',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLightColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  group.code,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppTheme.primaryColor),
                                  onPressed: () => _copyToClipboard(context, group.code),
                                  tooltip: 'Copy to Clipboard',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share this 6-digit alphanumeric code with friends. They can join VASL instantly.',
                              style: TextStyle(
                                color: AppTheme.textLightColor.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Settings Section (only shown if current user is Creator or Sub-Creator)
                      if (group.createdBy == currentUserId || group.admins.contains(currentUserId)) ...[
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Group Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textLightColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Lock Chat', style: TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: const Text('Only admins can send messages'),
                                value: group.isLocked,
                                activeThumbColor: AppTheme.primaryColor,
                                onChanged: (val) async {
                                  final success = await chatProvider.toggleLockGroup(group.id, val);
                                  if (!success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to update group lock settings.')),
                                    );
                                  }
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Private Group', style: TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: const Text('New members must request to join'),
                                value: group.privacy == 'private',
                                activeThumbColor: AppTheme.primaryColor,
                                onChanged: (val) async {
                                  final success = await chatProvider.updateGroupPrivacy(group.id, val ? 'private' : 'public');
                                  if (!success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to update group privacy settings.')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Pending Join Requests Section (only shown for moderators in private group)
                      if ((group.createdBy == currentUserId || group.admins.contains(currentUserId)) && 
                          group.privacy == 'private' && group.requests.isNotEmpty) ...[
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Join Requests (${group.requests.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textLightColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: group.requests.length,
                                itemBuilder: (context, index) {
                                  final reqUser = group.requests[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppTheme.otherBubbleColor,
                                      backgroundImage: reqUser.avatarUrl.isNotEmpty
                                          ? NetworkImage(reqUser.avatarUrl)
                                          : null,
                                      child: reqUser.avatarUrl.isEmpty
                                          ? const Icon(Icons.person, size: 18, color: Colors.grey)
                                          : null,
                                    ),
                                    title: Text(reqUser.username, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: AppTheme.successColor),
                                          onPressed: () async {
                                            final success = await chatProvider.approveJoinRequest(group.id, reqUser.userId);
                                            if (!success && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to approve request.')),
                                              );
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: AppTheme.errorColor),
                                          onPressed: () async {
                                            final success = await chatProvider.declineJoinRequest(group.id, reqUser.userId);
                                            if (!success && mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to decline request.')),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Members List Section
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Members (${group.resolvedMembers.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textLightColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: group.resolvedMembers.length,
                              itemBuilder: (context, index) {
                                final member = group.resolvedMembers[index];
                                final isMemberCreator = member.userId == group.createdBy;
                                final isMemberAdmin = group.admins.contains(member.userId);
                                
                                final bool isCreator = group.createdBy == currentUserId;
                                final bool isAdmin = group.admins.contains(currentUserId);
                                final bool canModerate = (isCreator && !isMemberCreator) ||
                                    (isAdmin && !isMemberCreator && !isMemberAdmin && member.userId != currentUserId);

                                Widget? trailingWidget;
                                if (isMemberCreator) {
                                  trailingWidget = Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.selfBubbleColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Creator',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                } else {
                                  List<Widget> rowItems = [];
                                  if (isMemberAdmin) {
                                    rowItems.add(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Admin',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (canModerate) {
                                    if (rowItems.isNotEmpty) rowItems.add(const SizedBox(width: 4));
                                    rowItems.add(
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 20),
                                        padding: EdgeInsets.zero,
                                        onSelected: (val) async {
                                          if (val == 'promote') {
                                            await chatProvider.promoteMember(group.id, member.userId);
                                          } else if (val == 'demote') {
                                            await chatProvider.demoteAdmin(group.id, member.userId);
                                          } else if (val == 'kick') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Kick Member'),
                                                content: Text('Are you sure you want to remove ${member.username}?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kick')),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await chatProvider.kickMember(group.id, member.userId);
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (isCreator)
                                            PopupMenuItem(
                                              value: isMemberAdmin ? 'demote' : 'promote',
                                              child: Text(isMemberAdmin ? 'Demote Admin' : 'Make Admin'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'kick',
                                            child: Text('Kick Member', style: TextStyle(color: AppTheme.errorColor)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  trailingWidget = rowItems.isNotEmpty
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: rowItems,
                                        )
                                      : null;
                                }

                                return ListTile(
                                  onTap: () => _showUserProfileDialog(context, member.userId, member.username, member.avatarUrl),
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.otherBubbleColor,
                                    backgroundImage: member.avatarUrl.isNotEmpty
                                        ? NetworkImage(member.avatarUrl)
                                        : null,
                                    child: member.avatarUrl.isEmpty
                                        ? const Icon(Icons.person, size: 18, color: Colors.grey)
                                        : null,
                                  ),
                                  title: Text(
                                    member.username,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  trailing: trailingWidget,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Delete Group Button (only visible to the Creator)
                      if (group.createdBy == currentUserId) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Group'),
                                  content: const Text('Are you sure you want to delete this group permanently? This will remove all messages and delete it from all members\' apps.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                final success = await chatProvider.deleteGroupPermanently(group.id);
                                if (success && mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Group deleted successfully.')),
                                  );
                                }
                              }
                            },
                            child: const Text('Delete Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
    );
  }
}
