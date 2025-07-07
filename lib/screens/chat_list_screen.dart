import 'package:flutter/material.dart';
import 'package:hanapp/models/conversation_preview.dart';
import 'package:hanapp/services/chat_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/screens/chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  User? _currentUser;
  bool _isLoadingUser = true;
  String? _userErrorMessage;
  List<ConversationPreview> _conversations = [];
  bool _isLoadingConversations = true;
  String? _conversationsErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndConversations();
  }

  Future<void> _loadCurrentUserAndConversations() async {
    setState(() {
      _isLoadingUser = true;
      _userErrorMessage = null;
    });

    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      _userErrorMessage = 'User not logged in. Please log in to view chats.';
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } else {
      await _fetchConversations();
    }

    setState(() {
      _isLoadingUser = false;
    });
  }

  Future<void> _fetchConversations() async {
    if (_currentUser == null) {
      _showSnackBar('User not authenticated.', isError: true);
      return;
    }

    setState(() {
      _isLoadingConversations = true;
      _conversationsErrorMessage = null;
      _conversations = [];
    });

    try {
      final response = await _chatService.getConversationsForUser(userId: _currentUser!.id!);
      if (response['success']) {
        setState(() {
          _conversations = response['conversations'];
        });
      } else {
        setState(() {
          _conversationsErrorMessage = response['message'] ?? 'Failed to load conversations.';
        });
      }
    } catch (e) {
      setState(() {
        _conversationsErrorMessage = 'Network error: $e';
        debugPrint('Error fetching conversations: $e');
      });
    } finally {
      setState(() {
        _isLoadingConversations = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats'), backgroundColor: Constants.primaryColor, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_userErrorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats'), backgroundColor: Constants.primaryColor, foregroundColor: Colors.white),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _userErrorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConversations,
        child: _isLoadingConversations
            ? const Center(child: CircularProgressIndicator())
            : _conversationsErrorMessage != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _conversationsErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        )
            : _conversations.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No conversations yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Start by applying for jobs or connecting with applicants!',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: _conversations.length,
          itemBuilder: (context, index) {
            final conversation = _conversations[index];
            final bool isListerForThisConversation = _currentUser!.id == conversation.listerId;

            return Card(
              margin: const EdgeInsets.only(bottom: 10.0),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: (conversation.otherUserProfilePictureUrl != null && conversation.otherUserProfilePictureUrl!.isNotEmpty)
                      ? NetworkImage(conversation.otherUserProfilePictureUrl!) as ImageProvider
                      : const AssetImage('assets/dashboard_image.png') as ImageProvider,
                ),
                title: Text(
                  conversation.listingTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.otherUserName,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    Text(
                      conversation.lastMessageContent ?? 'No messages yet.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Text(
                  conversation.getLastMessageTimeAgo(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversationId: conversation.conversationId,
                        otherUserId: conversation.otherUserId,
                        listingTitle: conversation.listingTitle,
                        // Correctly pass applicationId (now non-nullable)
                        applicationId: conversation.applicationId,
                        isLister: isListerForThisConversation,

                      ),
                    ),
                  ).then((_) {
                    _fetchConversations();
                  });
                },
              ),
            );
          },
        ),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed,
      //   selectedItemColor: Constants.primaryColor,
      //   unselectedItemColor: Colors.grey,
      //   currentIndex: 2,
      //   onTap: (index) {
      //     if (index == 0) {
      //       Navigator.of(context).pushReplacementNamed('/doer_dashboard');
      //     } else if (index == 1) {
      //       Navigator.of(context).pushReplacementNamed('/job_listings');
      //     } else if (index == 2) {
      //       // Already on Chat List (this screen)
      //     } else if (index == 3) {
      //       _showSnackBar('Notifications (Coming Soon)');
      //     } else if (index == 4) {
      //       _showSnackBar('Profile (Coming Soon)');
      //     }
      //   },
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.home),
      //       label: 'Home',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.check_circle),
      //       label: 'Jobs',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.chat),
      //       label: 'Chats',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.notifications),
      //       label: 'Notifications',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.person),
      //       label: 'Profile',
      //     ),
      //   ],
      // ),
    );
  }
}
