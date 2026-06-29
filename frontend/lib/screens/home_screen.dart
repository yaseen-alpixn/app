import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch user groups once user is authenticated/cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isRegistered) {
        Provider.of<ChatProvider>(context, listen: false)
            .loadGroups(auth.currentUser!.userId);
      }
    });
  }

  /// Intercept FAB clicks if the profile is not registered
  bool _checkProfileRegistered(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isRegistered) {
      _showRegistrationPrompt(context);
      return false;
    }
    return true;
  }

  /// Show sleek bottom sheet prompting user to configure profile
  void _showRegistrationPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle, size: 64, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Profile Setup Required',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'You must set up a username before you can create or join group chats.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                  child: const Text('Configure Profile Name'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show Dialog to Create Group
  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Enter group name',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                
                Navigator.pop(context);
                
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                
                final newGroup = await chatProvider.createGroup(name, auth.currentUser!.userId);
                
                if (newGroup != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(groupId: newGroup.id, groupName: newGroup.name),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(chatProvider.errorMessage ?? 'Failed to create group.'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  /// Show Dialog to Join Group
  void _showJoinGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Group via Code'),
          content: TextField(
            controller: controller,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Enter 6-digit code (e.g. X79R2W)',
              prefixIcon: Icon(Icons.vpn_key_outlined),
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = controller.text.trim().toUpperCase();
                if (code.length != 6) return;
                
                Navigator.pop(context);
                
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                
                final joinedGroup = await chatProvider.joinGroup(code, auth.currentUser!.userId);
                
                if (joinedGroup != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(groupId: joinedGroup.id, groupName: joinedGroup.name),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(chatProvider.errorMessage ?? 'Failed to join group.'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  /// Expand speed-dial options menu using a clean Bottom Sheet
  void _showFabMenu(BuildContext context) {
    if (!_checkProfileRegistered(context)) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.selfBubbleColor,
                  child: Icon(Icons.add, color: AppTheme.primaryColor),
                ),
                title: const Text('1. Create Group'),
                subtitle: const Text('Generate a unique 6-digit invite code'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateGroupDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.otherBubbleColor,
                  child: Icon(Icons.group_add, color: Colors.blue),
                ),
                title: const Text('2. Join Group'),
                subtitle: const Text('Enter code to instantly enter a chat room'),
                onTap: () {
                  Navigator.pop(context);
                  _showJoinGroupDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final socketService = Provider.of<SocketService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VASL'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: auth.currentUser?.avatarUrl.isNotEmpty == true
                  ? NetworkImage(auth.currentUser!.avatarUrl)
                  : null,
              child: auth.currentUser?.avatarUrl.isEmpty == true
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Real-time Connection Status Indicator Banner (Wi-Fi/mobile data recovery hooks)
          if (!socketService.isConnected && auth.isRegistered)
            Container(
              color: socketService.isConnecting ? Colors.orange.shade800 : AppTheme.errorColor,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    socketService.isConnecting ? 'Reconnecting to VASL...' : 'Offline. Reconnecting...',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // Chats list
          Expanded(
            child: auth.isLoading
                ? const Center(child: CircularProgressIndicator())
                : !auth.isRegistered
                    ? _buildUnregisteredState()
                    : chatProvider.isLoadingGroups
                        ? const Center(child: CircularProgressIndicator())
                        : chatProvider.groups.isEmpty
                            ? _buildEmptyGroupsState()
                            : RefreshIndicator(
                                onRefresh: () => chatProvider.loadGroups(auth.currentUser!.userId),
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: chatProvider.groups.length,
                                  itemBuilder: (context, index) {
                                    final group = chatProvider.groups[index];
                                    final messages = chatProvider.getMessages(group.id);
                                    
                                    // Fetch last message details
                                    final lastMessage = messages.isNotEmpty ? messages.last : null;
                                    final timeText = lastMessage != null
                                        ? '${lastMessage.timestamp.hour.toString().padLeft(2, '0')}:${lastMessage.timestamp.minute.toString().padLeft(2, '0')}'
                                        : '';

                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: CircleAvatar(
                                            radius: 24,
                                            backgroundColor: AppTheme.selfBubbleColor,
                                            backgroundImage: group.avatarUrl.isNotEmpty
                                                ? NetworkImage(group.avatarUrl)
                                                : null,
                                            child: group.avatarUrl.isEmpty
                                                ? Text(
                                                    group.name.substring(0, 1).toUpperCase(),
                                                    style: const TextStyle(
                                                      color: AppTheme.primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          title: Text(
                                            group.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          subtitle: Text(
                                            lastMessage != null ? '${lastMessage.senderName}: ${lastMessage.text}' : 'Tap to chat',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: lastMessage != null ? AppTheme.textDarkColor.withValues(alpha: 0.8) : AppTheme.textLightColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                          trailing: Text(
                                            timeText,
                                            style: const TextStyle(color: AppTheme.textLightColor, fontSize: 12),
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatScreen(
                                                  groupId: group.id,
                                                  groupName: group.name,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const Divider(height: 1, indent: 72),
                                      ],
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFabMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUnregisteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.jpeg',
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to VASL',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'To start chatting, configure your profile name first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textLightColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              icon: const Icon(Icons.person),
              label: const Text('Configure Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGroupsState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Active Chats',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the "+" button below to Create or Join a group via invite codes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textLightColor),
            ),
          ],
        ),
      ),
    );
  }
}
