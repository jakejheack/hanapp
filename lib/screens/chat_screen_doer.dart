// import 'package:flutter/material.dart';
// import 'package:hanapp/utils/auth_service.dart';
// import 'package:hanapp/utils/listing_service.dart';
// import 'package:hanapp/models/user.dart';
// import 'package:hanapp/models/message.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:intl/intl.dart';
//
// class ChatScreenDoer extends StatefulWidget {
//   const ChatScreenDoer({super.key});
//
//   @override
//   State<ChatScreenDoer> createState() => _ChatScreenDoerState();
// }
//
// class _ChatScreenDoerState extends State<ChatScreenDoer> {
//   final TextEditingController _messageController = TextEditingController();
//   final ListingService _listingService = ListingService();
//   User? _currentUser;
//   int? _listingId;
//   int? _applicationId; // NEW: To manage application status for lister
//   bool _isLister = false; // NEW: To show/hide Reject/Start buttons
//
//   List<Message> _messages = [];
//   bool _isLoadingMessages = true;
//   bool _isSendingMessage = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCurrentUser();
//   }
//
//   Future<void> _loadCurrentUser() async {
//     _currentUser = await AuthService.getUser();
//     setState(() {}); // Rebuild to ensure _currentUser is available for didChangeDependencies
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Access arguments directly from ModalRoute
//     final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
//
//     // Store only the arguments that are still state variables
//     _listingId = args['listingId'];
//     _applicationId = args['applicationId'];
//     _isLister = args['isLister'] ?? false; // Default to false if not provided
//
//     // Get recipientId from arguments to pass to fetchMessages
//     final int? recipientId = args['recipientId'];
//     if (_currentUser != null && recipientId != null) {
//       _fetchMessages(recipientId);
//     }
//   }
//
//   Future<void> _fetchMessages(int recipientId) async {
//     if (_currentUser == null) return;
//
//     setState(() {
//       _isLoadingMessages = true;
//     });
//
//     final response = await _listingService.getMessages(
//       user1Id: _currentUser!.id,
//       user2Id: recipientId,
//       listingId: _listingId,
//     );
//
//     setState(() {
//       _isLoadingMessages = false;
//       if (response['success']) {
//         _messages = response['messages'].cast<Message>();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to load messages: ${response['message']}')),
//         );
//       }
//     });
//   }
//
//   Future<void> _sendMessage(int recipientId) async {
//     if (_messageController.text.trim().isEmpty || _currentUser == null) {
//       return;
//     }
//
//     setState(() {
//       _isSendingMessage = true;
//     });
//
//     final response = await _listingService.sendMessage(
//       senderId: _currentUser!.id,
//       receiverId: recipientId,
//       messageText: _messageController.text.trim(),
//       listingId: _listingId,
//     );
//
//     setState(() {
//       _isSendingMessage = false;
//       _messageController.clear();
//     });
//
//     if (response['success']) {
//       _fetchMessages(recipientId); // Refresh messages after sending
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to send message: ${response['message']}')),
//       );
//     }
//   }
//
//   Future<void> _updateApplicationStatus(String status) async {
//     if (_applicationId == null || _currentUser == null || _currentUser!.id == null) return;
//
//     setState(() {
//       _isLoadingMessages = true; // Use loading indicator for status update too
//     });
//
//     final response = await _listingService.updateApplicationStatus(
//       applicationId: _applicationId!,
//       status: status,
//       initiatorId: _currentUser!.id!,
//     );
//
//     setState(() {
//       _isLoadingMessages = false;
//     });
//
//     if (response['success']) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(response['message'])),
//       );
//       // Optionally, navigate back or refresh listing details screen
//       Navigator.of(context).pop();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update status: ${response['message']}')),
//       );
//     }
//   }
//
//   Widget _buildMessage(Message message) {
//     final bool isMe = message.senderId == _currentUser!.id;
//     return Align(
//       alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
//         padding: const EdgeInsets.all(12.0),
//         decoration: BoxDecoration(
//           color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(12.0),
//         ),
//         child: Column(
//           crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//           children: [
//             Text(
//               message.messageText,
//               style: const TextStyle(fontSize: 16.0),
//             ),
//             const SizedBox(height: 4.0),
//             Text(
//               DateFormat('hh:mm a').format(message.sentAt),
//               style: TextStyle(fontSize: 10.0, color: Colors.grey.shade600),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Access arguments directly within build
//     final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
//     final String? recipientName = args['recipientName'];
//     final int? recipientId = args['recipientId'];
//
//     if (_currentUser == null || recipientId == null || _isLoadingMessages) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Loading Chat...')),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF141CC9), // HANAPP Blue
//         foregroundColor: Colors.white,
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               recipientName ?? 'Chat',
//               style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             if (_listingId != null)
//               Text(
//                 'Listing ID: $_listingId', // You might want to fetch listing title here
//                 style: const TextStyle(fontSize: 12, color: Colors.white70),
//               ),
//           ],
//         ),
//       ),
//       body: Column(
//         children: [
//           // Reject / Start buttons (only for lister)
//           if (_isLister)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () => _updateApplicationStatus('rejected'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.red.shade400,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                       ),
//                       child: const Text('Reject'),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: () => _updateApplicationStatus('hired'), // Or 'accepted' then 'hired'
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green.shade400,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                         padding: const EdgeInsets.symmetric(vertical: 12),
//                       ),
//                       child: const Text('Start'),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           Expanded(
//             child: ListView.builder(
//               reverse: false, // Display new messages at the bottom
//               padding: const EdgeInsets.all(8.0),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 return _buildMessage(_messages[index]);
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Type a message',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24.0),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey.shade200,
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//                     ),
//                     onSubmitted: (value) => _sendMessage(recipientId), // Pass recipientId
//                   ),
//                 ),
//                 const SizedBox(width: 8.0),
//                 _isSendingMessage
//                     ? const CircularProgressIndicator()
//                     : FloatingActionButton(
//                   onPressed: () => _sendMessage(recipientId), // Pass recipientId
//                   backgroundColor: const Color(0xFF141CC9),
//                   mini: true,
//                   child: const Icon(Icons.send, color: Colors.white),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
