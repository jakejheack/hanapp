// import 'package:flutter/material.dart';
// import 'package:hanapp/models/conversation.dart';
// import 'package:hanapp/models/user.dart';
// import 'package:hanapp/services/chat_service.dart';
// import 'package:hanapp/utils/auth_service.dart';
// import 'package:hanapp/utils/constants.dart' as Constants;
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:intl/intl.dart';
// import 'package:hanapp/screens/chat_screen.dart'; // Import the ChatScreen
//
// class UnifiedConversationsScreen extends StatefulWidget {
//   const UnifiedConversationsScreen({super.key});
//
//   @override
//   State<UnifiedConversationsScreen> createState() => _UnifiedConversationsScreenState();
// }
//
// class _UnifiedConversationsScreenState extends State<UnifiedConversationsScreen> {
//   User? _currentUser;
//   List<Conversation> _conversations = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//
//   final ChatService _chatService = ChatService();
//
//   @override
//   void initState() {
//     super.initState();
//     _loadConversations();
//   }
//
//   Future<void> _loadConversations() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//       _conversations = []; // Clear previous data
//     });
//
//     try {
//       _currentUser = await AuthService.getUser();
//       if (_currentUser == null || _currentUser!.id == null) {
//         _errorMessage = 'User not logged in. Please log in.';
//         if (mounted) Navigator.of(context).pushReplacementNamed('/login');
//         return;
//       }
//
//       final response = await _chatService.getUserConversations(userId: _currentUser!.id!);
//       if (response['success']) {
//         setState(() {
//           _conversations = response['conversations'];
//         });
//       } else {
//         _errorMessage = response['message'] ?? 'Failed to load conversations.';
//       }
//     } catch (e) {
//       _errorMessage = 'Network error: $e';
//       debugPrint('Error loading conversations: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _showSnackBar(String message, {bool isError = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(
//               isError ? Icons.error_outline : Icons.check_circle_outline,
//               color: Colors.white,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 message,
//                 style: const TextStyle(color: Colors.white),
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: isError ? Colors.red : Colors.green,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         margin: const EdgeInsets.all(10),
//       ),
//     );
//   }
//
//   void _navigateToChatScreen(Conversation conversation) {
//     if (mounted) {
//       Navigator.of(context).push(
//         MaterialPageRoute(
//           builder: (context) => ChatScreen(
//             conversationId: conversation.id,
//             otherUserId: conversation.otherUserId,
//             listingTitle: conversation.listingTitle,
//             applicationId: conversation.applicationId ?? 0, // Pass the application ID, default to 0 if null
//           ),
//         ),
//       ).then((_) {
//         // When returning from ChatScreen, refresh the conversation list
//         _loadConversations();
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Messages'),
//         backgroundColor: Constants.primaryColor,
//         foregroundColor: Colors.white,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _errorMessage != null
//           ? Center(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Text(
//             _errorMessage!,
//             textAlign: TextAlign.center,
//             style: const TextStyle(color: Colors.red, fontSize: 16),
//           ),
//         ),
//       )
//           : _conversations.isEmpty
//           ? const Center(
//         child: Text(
//           'No conversations yet.',
//           style: TextStyle(fontSize: 16, color: Colors.grey),
//         ),
//       )
//           : RefreshIndicator(
//         onRefresh: _loadConversations,
//         child: ListView.builder(
//           padding: const EdgeInsets.all(16.0),
//           itemCount: _conversations.length,
//           itemBuilder: (context, index) {
//             final conversation = _conversations[index];
//             return Card(
//               margin: const EdgeInsets.only(bottom: 12.0),
//               elevation: 2,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: InkWell(
//                 onTap: () => _navigateToChatScreen(conversation),
//                 borderRadius: BorderRadius.circular(12),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       CircleAvatar(
//                         radius: 30,
//                         backgroundImage: (conversation.otherUserProfilePictureUrl != null && conversation.otherUserProfilePictureUrl!.isNotEmpty)
//                             ? CachedNetworkImageProvider(conversation.otherUserProfilePictureUrl!)
//                             : const AssetImage('assets/default_profile.png') as ImageProvider,
//                         backgroundColor: Colors.grey.shade200,
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     conversation.otherUserFullName,
//                                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ),
//                                 Text(
//                                   DateFormat('MMM d').format(conversation.lastMessageSentAt),
//                                   style: const TextStyle(fontSize: 13, color: Colors.grey),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               conversation.listingTitle,
//                               style: const TextStyle(fontSize: 15, color: Constants.primaryColor, fontWeight: FontWeight.w500),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               conversation.lastMessageContent,
//                               style: const TextStyle(fontSize: 14, color: Colors.grey),
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
