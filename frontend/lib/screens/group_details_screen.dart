import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final group = chatProvider.getDetails(widget.groupId);
    final isLoading = chatProvider.isDetailsLoading(widget.groupId);

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
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppTheme.selfBubbleColor,
                              child: Text(
                                group.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                final isCreator = member.userId == group.createdBy;

                                return ListTile(
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
                                  trailing: isCreator
                                      ? Container(
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
                                        )
                                      : null,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
