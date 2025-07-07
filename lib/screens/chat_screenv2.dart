// import 'package:flutter/material.dart';
// import 'package:hanapp/models/conversation.dart';
// import 'package:hanapp/models/message.dart';
// import 'package:hanapp/models/user.dart';
// import 'package:hanapp/services/chat_service.dart';
// import 'package:hanapp/utils/auth_service.dart';
// import 'package:hanapp/utils/constants.dart' as Constants;
// import 'package:cached_network_image/cached_network_image.dart';
// import 'dart:async'; // For Timer
//
// class ChatScreen extends StatefulWidget {
//   final int conversationId; // The ID of the conversation to display
//   final int otherUserId;    // The ID of the other participant in the chat
//   final String listingTitle; // Title of the listing related to the chat
//
//   const ChatScreen({
//     super.key,
//     required this.conversationId,
//     required this.otherUserId,
//     required this.listingTitle,
//   });
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final ChatService _chatService = ChatService();
//   User? _currentUser;
//   User? _otherUser; // Details of the other participant
//   List<Message> _messages = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   Timer? _pollingTimer; // For periodic message fetching
//   int _lastMessageId = 0; // To fetch only new messages
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeChat();
//   }
//
//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     _pollingTimer?.cancel(); // Cancel timer when screen is disposed
//     super.dispose();
//   }
//
//   Future<void> _initializeChat() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       _currentUser = await AuthService.getUser();
//       if (_currentUser == null) {
//         _errorMessage = 'User not logged in.';
//         if (mounted) Navigator.of(context).pushReplacementNamed('/login');
//         return;
//       }
//
//       // Fetch details of the other user for the header
//       final otherUserResponse = await AuthService().getUserDetailsById(widget.otherUserId);
//       if (otherUserResponse['success']) {
//         _otherUser = otherUserResponse['user'];
//       } else {
//         _errorMessage = otherUserResponse['message'] ?? 'Failed to load other user details.';
//         return;
//       }
//
//       await _fetchMessages(); // Fetch initial messages
//       _startPolling(); // Start polling for new messages
//     } catch (e) {
//       _errorMessage = 'Error initializing chat: $e';
//       debugPrint('ChatScreen: Initialization Error: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _fetchMessages({bool scrollToBottom = true}) async {
//     try {
//       final response = await _chatService.getMessages(
//         conversationId: widget.conversationId,
//         lastMessageId: _lastMessageId, // Only fetch messages newer than this ID
//       );
//       if (response['success']) {
//         List<Message> newMessages = response['messages'];
//         if (newMessages.isNotEmpty) {
//           setState(() {
//             _messages.addAll(newMessages);
//             _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt)); // Ensure chronological order
//             _lastMessageId = _messages.last.id; // Update last message ID
//           });
//           if (scrollToBottom) {
//             _scrollToBottom();
//           }
//         }
//       } else {
//         debugPrint('ChatScreen: Failed to fetch messages: ${response['message']}');
//         // Don't show snackbar for every polling error, just log
//       }
//     } catch (e) {
//       debugPrint('ChatScreen: Error fetching messages: $e');
//     }
//   }
//
//   void _startPolling() {
//     _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
//       // Fetch new messages without scrolling to bottom unless explicitly new user message
//       _fetchMessages(scrollToBottom: false);
//     });
//   }
//
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   Future<void> _sendMessage() async {
//     if (_messageController.text.trim().isEmpty || _currentUser == null || _otherUser == null) {
//       return;
//     }
//
//     final String messageText = _messageController.text.trim();
//     _messageController.clear(); // Clear input immediately
//
//     // Optimistically add message to UI
//     final tempMessage = Message(
//       id: 0, // Temporary ID
//       conversationId: widget.conversationId,
//       senderId: _currentUser!.id,
//       receiverId: widget.otherUserId,
//       messageText: messageText,
//       sentAt: DateTime.now(),
//       isRead: false,
//       sender: _currentUser,
//       receiver: _otherUser,
//     );
//
//     setState(() {
//       _messages.add(tempMessage);
//     });
//     _scrollToBottom();
//
//     final response = await _chatService.sendMessage(
//       conversationId: widget.conversationId,
//       senderId: _currentUser!.id,
//       receiverId: widget.otherUserId,
//       messageText: messageText,
//     );
//
//     if (response['success']) {
//       // Message successfully sent, update temp message with real ID if needed
//       // For simplicity, we'll let the next poll update the messages list
//       debugPrint('ChatScreen: Message sent successfully.');
//       // A small delay before re-fetching to ensure backend has processed
//       Future.delayed(const Duration(milliseconds: 500), () => _fetchMessages());
//     } else {
//       _showSnackBar('Failed to send message: ${response['message']}', isError: true);
//       // Remove optimistic message if sending failed
//       setState(() {
//         _messages.remove(tempMessage);
//       });
//     }
//   }
//
//   void _showSnackBar(String message, {bool isError = false}) {
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
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('Chat'),
//           backgroundColor: Constants.primaryColor,
//           foregroundColor: Colors.white,
//         ),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     if (_errorMessage != null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('Chat Error'),
//           backgroundColor: Constants.primaryColor,
//           foregroundColor: Colors.white,
//         ),
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               _errorMessage!,
//               style: const TextStyle(color: Colors.red, fontSize: 16),
//               textAlign: TextAlign.center,
//             ),
//           ),
//         ),
//       );
//     }
//
//     // Determine the other user's profile picture
//     ImageProvider<Object>? otherUserProfileImage;
//     if (_otherUser?.profilePictureUrl != null && _otherUser!.profilePictureUrl!.isNotEmpty) {
//       otherUserProfileImage = CachedNetworkImageProvider(_otherUser!.profilePictureUrl!);
//     } else {
//       otherUserProfileImage = const AssetImage('assets/default_profile.png');
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Constants.primaryColor,
//         foregroundColor: Colors.white,
//         titleSpacing: 0, // Remove default title spacing
//         title: Row(
//           children: [
//             CircleAvatar(
//               radius: 20,
//               backgroundImage: otherUserProfileImage,
//               backgroundColor: Colors.grey.shade200,
//             ),
//             const SizedBox(width: 10),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _otherUser?.fullName ?? 'Unknown User',
//                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 Text(
//                   _otherUser?.addressDetails ?? 'Location not set',
//                   style: const TextStyle(fontSize: 14, color: Colors.white70),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.more_vert),
//             onPressed: () {
//               // TODO: Implement more options (e.g., view profile, report)
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Listing Title and Action Buttons (visible if current user is Lister)
//           if (_currentUser?.role == 'lister')
//             Container(
//               padding: const EdgeInsets.all(16.0),
//               color: Colors.grey.shade100,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     widget.listingTitle,
//                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: () {
//                             // TODO: Implement Reject logic (e.g., update application status)
//                             _showSnackBar('Reject button pressed (Placeholder)');
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.red.shade400,
//                             foregroundColor: Colors.white,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           child: const Text('Reject'),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: () {
//                             // TODO: Implement Start logic (e.g., update application/listing status)
//                             _showSnackBar('Start button pressed (Placeholder)');
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green.shade400,
//                             foregroundColor: Colors.white,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                           child: const Text('Start'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           // Chat Messages Area
//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final message = _messages[index];
//                 final bool isMe = message.senderId == _currentUser!.id;
//                 return _buildMessageBubble(message, isMe);
//               },
//             ),
//           ),
//           // Message Input Area
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.1),
//                   spreadRadius: 1,
//                   blurRadius: 5,
//                   offset: const Offset(0, -3),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.attach_file, color: Constants.textColor),
//                   onPressed: () {
//                     // TODO: Implement attachment functionality
//                     _showSnackBar('Attachment (Not implemented yet)');
//                   },
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.mic, color: Constants.textColor),
//                   onPressed: () {
//                     // TODO: Implement voice message functionality
//                     _showSnackBar('Voice message (Not implemented yet)');
//                   },
//                 ),
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Type a message',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(25.0),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey.shade200,
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                     ),
//                     maxLines: null, // Allow multiple lines
//                     keyboardType: TextInputType.multiline,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 ElevatedButton(
//                   onPressed: _sendMessage,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Constants.primaryColor,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                   ),
//                   child: const Text('Send'),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageBubble(Message message, bool isMe) {
//     // Determine the sender's profile picture for the bubble
//     ImageProvider<Object>? senderProfileImage;
//     if (message.sender?.profilePictureUrl != null && message.sender!.profilePictureUrl!.isNotEmpty) {
//       senderProfileImage = CachedNetworkImageProvider(message.sender!.profilePictureUrl!);
//     } else {
//       senderProfileImage = const AssetImage('assets/default_profile.png');
//     }
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.end, // Align avatar/bubble
//         children: [
//           if (!isMe) // Show avatar for incoming messages
//             Padding(
//               padding: const EdgeInsets.only(right: 8.0),
//               child: CircleAvatar(
//                 radius: 18,
//                 backgroundImage: senderProfileImage,
//                 backgroundColor: Colors.grey.shade200,
//               ),
//             ),
//           Flexible(
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
//               margin: EdgeInsets.only(
//                 top: 4,
//                 bottom: 4,
//                 left: isMe ? 50.0 : 0, // More margin on left for my messages
//                 right: isMe ? 0 : 50.0, // More margin on right for others' messages
//               ),
//               decoration: BoxDecoration(
//                 color: isMe ? Constants.primaryColor : Colors.grey.shade200,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(isMe ? 15 : 0),
//                   topRight: Radius.circular(isMe ? 0 : 15),
//                   bottomLeft: const Radius.circular(15),
//                   bottomRight: const Radius.circular(15),
//                 ),
//               ),
//               child: Text(
//                 message.messageText,
//                 style: TextStyle(
//                   color: isMe ? Colors.white : Constants.textColor,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ),
//           if (isMe) // Show avatar for outgoing messages (optional, or just for verification)
//             Padding(
//               padding: const EdgeInsets.only(left: 8.0),
//               child: CircleAvatar(
//                 radius: 18,
//                 backgroundImage: senderProfileImage,
//                 backgroundColor: Colors.grey.shade200,
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
