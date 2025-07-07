// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart'; // For debugPrint
// import 'package:hanapp/utils/api_config.dart'; // Ensure correct path
// import 'package:hanapp/models/conversation.dart';
// import 'package:hanapp/models/message.dart';
//
// class ChatService {
//   // Creates a new conversation or returns an existing one
//   Future<Map<String, dynamic>> createOrGetConversation({
//     required int listingId,
//     required String listingType,
//     required int listerId,
//     required int doerId,
//   }) async {
//     final url = Uri.parse(ApiConfig.createConversationEndpoint);
//     debugPrint('ChatService: Creating/Getting conversation for listing $listingId ($listingType) between lister $listerId and doer $doerId');
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'listing_id': listingId,
//           'listing_type': listingType,
//           'lister_id': listerId,
//           'doer_id': doerId,
//         }),
//       );
//       final responseData = json.decode(response.body);
//       debugPrint('ChatService: Create/Get Conversation Response: $responseData');
//
//       if (response.statusCode == 200 && responseData['success']) {
//         return {'success': true, 'conversation_id': responseData['conversation_id']};
//       } else {
//         return {'success': false, 'message': responseData['message'] ?? 'Failed to create/get conversation.'};
//       }
//     } catch (e) {
//       debugPrint('ChatService: Error creating/getting conversation: $e');
//       return {'success': false, 'message': 'Network error: $e'};
//     }
//   }
//
//   // Fetches details of a specific conversation
//   Future<Map<String, dynamic>> getConversationDetails(int conversationId) async {
//     final url = Uri.parse('${ApiConfig.getConversationDetailsEndpoint}?conversation_id=$conversationId');
//     debugPrint('ChatService: Fetching conversation details for ID: $conversationId');
//
//     try {
//       final response = await http.get(url);
//       final responseData = json.decode(response.body);
//       debugPrint('ChatService: Get Conversation Details Response: $responseData');
//
//       if (response.statusCode == 200 && responseData['success']) {
//         return {'success': true, 'conversation': Conversation.fromJson(responseData['conversation'])};
//       } else {
//         return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch conversation details.'};
//       }
//     } catch (e) {
//       debugPrint('ChatService: Error fetching conversation details: $e');
//       return {'success': false, 'message': 'Network error: $e'};
//     }
//   }
//
//   // Sends a message
//   Future<Map<String, dynamic>> sendMessage({
//     required int conversationId,
//     required int senderId,
//     required int receiverId,
//     required String messageText,
//   }) async {
//     final url = Uri.parse(ApiConfig.sendMessageEndpoint);
//     debugPrint('ChatService: Sending message in conversation $conversationId from $senderId to $receiverId');
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'conversation_id': conversationId,
//           'sender_id': senderId,
//           'receiver_id': receiverId,
//           'message_text': messageText,
//         }),
//       );
//       final responseData = json.decode(response.body);
//       debugPrint('ChatService: Send Message Response: $responseData');
//
//       if (response.statusCode == 200 && responseData['success']) {
//         return {'success': true, 'message_id': responseData['message_id']};
//       } else {
//         return {'success': false, 'message': responseData['message'] ?? 'Failed to send message.'};
//       }
//     } catch (e) {
//       debugPrint('ChatService: Error sending message: $e');
//       return {'success': false, 'message': 'Network error: $e'};
//     }
//   }
//
//   // Fetches messages for a conversation
//   Future<Map<String, dynamic>> getMessages({
//     required int conversationId,
//     int lastMessageId = 0, // For polling new messages
//   }) async {
//     final url = Uri.parse('${ApiConfig.getMessagesEndpoint}?conversation_id=$conversationId&last_message_id=$lastMessageId');
//     debugPrint('ChatService: Fetching messages for conversation $conversationId (last_message_id: $lastMessageId)');
//
//     try {
//       final response = await http.get(url);
//       final responseData = json.decode(response.body);
//       // debugPrint('ChatService: Get Messages Response: $responseData'); // Can be noisy
//
//       if (response.statusCode == 200 && responseData['success']) {
//         List<Message> messages = (responseData['messages'] as List)
//             .map((messageJson) => Message.fromJson(messageJson))
//             .toList();
//         return {'success': true, 'messages': messages};
//       } else {
//         return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch messages.'};
//       }
//     } catch (e) {
//       debugPrint('ChatService: Error fetching messages: $e');
//       return {'success': false, 'message': 'Network error: $e'};
//     }
//   }
// }
