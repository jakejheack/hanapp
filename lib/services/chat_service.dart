import 'dart:convert';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:http/http.dart' as http;
import 'package:hanapp/models/message.dart';

import '../models/conversation_preview.dart';
import '../utils/api_config.dart'; // Make sure Message model is imported

class ChatService {
  final String _baseUrl = ApiConfig.baseUrl; // Assuming this points to your backend root

  // Method to create a new conversation or get an existing one
  Future<Map<String, dynamic>> createOrGetConversation({
    required int listerId,
    required int doerId,
    required int listingId,
    required String listingType,
  }) async {
    final url = Uri.parse('$_baseUrl/chat/create_conversation.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lister_id': listerId,
          'doer_id': doerId,
          'listing_id': listingId,
          'listing_type': listingType,
        }),
      );

      final responseBody = json.decode(response.body);
      print('ChatService: Raw Response Body (Status: ${response.statusCode}): ${response.body}');
      print('ChatService: Decoded Response Data: $responseBody');

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to create/get conversation. Status: ${response.statusCode}'};
      }
    } catch (e) {
      print('ChatService: Error creating/getting conversation: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Method to fetch conversation details
  Future<Map<String, dynamic>> getConversationDetails(int conversationId) async {
    final url = Uri.parse('$_baseUrl/chat/get_conversation_details.php?conversation_id=$conversationId');
    try {
      final response = await http.get(url);
      final responseBody = json.decode(response.body);
      print('ChatService: Get Conversation Details Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return responseBody;
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load conversation details. Status: ${response.statusCode}'};
      }
    } catch (e) {
      print('ChatService: Error fetching conversation details: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // // Method to send a message
  // Future<Map<String, dynamic>> sendMessage({
  //   required int conversationId,
  //   required int senderId,
  //   required int receiverId,
  //   required String messageContent,
  //   required String messageType, // e.g., 'text', 'system', 'location_share'
  //   Map<String, dynamic>? locationData, // New optional parameter for location data
  // }) async {
  //   final url = Uri.parse('$_baseUrl/chat/send_message.php');
  //   try {
  //     final Map<String, dynamic> body = {
  //       'conversation_id': conversationId,
  //       'sender_id': senderId,
  //       'receiver_id': receiverId,
  //       'message_content': messageContent,
  //       'message_type': messageType,
  //     };
  //
  //     if (locationData != null) {
  //       body['location_data'] = locationData; // Add location data to the body
  //     }
  //
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: json.encode(body),
  //     );
  //
  //     final responseBody = json.decode(response.body);
  //     print('ChatService: Send Message Response: $responseBody');
  //
  //     if (response.statusCode == 200 && responseBody['success']) {
  //       return responseBody;
  //     } else {
  //       return {'success': false, 'message': responseBody['message'] ?? 'Failed to send message. Status: ${response.statusCode}'};
  //     }
  //   } catch (e) {
  //     print('ChatService: Error sending message: $e');
  //     return {'success': false, 'message': 'Network error: $e'};
  //   }
  // }
  /// Sends a new message within a conversation.
  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required int senderId,
    required int receiverId,
    required String messageContent, // Renamed from messageText for consistency with backend
    required String messageType, // e.g., 'text', 'location_share'
    Map<String, dynamic>? locationData, // Optional location data
    String? listingTitle, // NEW: For notification content
    final int? conversationListerId, // NEW: For notification context
    final int? conversationDoerId, // NEW: For notification context
    final int? applicationId, // NEW: For notification context
  }) async {
    final url = Uri.parse('$_baseUrl/chat/send_message.php');
    print('ChatService: Sending message to URL: $url');
    print('ChatService: Payload - Conversation ID: $conversationId, Sender ID: $senderId, Receiver ID: $receiverId, Content: $messageContent, Type: $messageType, Location: $locationData, Listing Title: $listingTitle, Lister ID: $conversationListerId, Doer ID: $conversationDoerId, Application ID: $applicationId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'message_content': messageContent, // Backend expects message_content
          'message_type': messageType,
          'location_data': locationData,
          'listing_title': listingTitle, // Pass to backend
          'conversation_lister_id': conversationListerId, // Pass to backend
          'conversation_doer_id': conversationDoerId, // Pass to backend
          'application_id': applicationId, // Pass to backend
        }),
      );
      final decodedResponse = json.decode(response.body);

      print('ChatService Send Message Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        return {'success': true, 'message': decodedResponse['message']};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to send message.'};
      }
    } catch (e) {
      print('ChatService Error sending message: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // Method to fetch messages
  Future<Map<String, dynamic>> getMessages({
    required int conversationId,
    required int lastMessageId,
  }) async {
    final url = Uri.parse('$_baseUrl/chat/get_messages.php?conversation_id=$conversationId&last_message_id=$lastMessageId');
    print('ChatService: Fetching messages from URL: $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('ChatService Get Messages Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        // Return the raw messages data instead of converting to Message objects
        return {'success': true, 'messages': decodedResponse['messages']};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch messages.'};
      }
    } catch (e) {
      print('ChatService Error fetching messages: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Method to start a project (update application status)
  Future<Map<String, dynamic>> startProject({
    required int applicationId,
    required int listerId,
    required String listerFullName,
  }) async {
    final url = Uri.parse('$_baseUrl/applications/update_application_status.php'); // Assuming this endpoint handles status updates
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'new_status': 'in_progress', // Reverted back to 'new_status'
          'current_user_id': listerId, // Reverted back to 'current_user_id'
        }),
      );

      final responseBody = json.decode(response.body);
      print('ChatService: Start Project Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return responseBody;
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to start project. Status: ${response.statusCode}'};
      }
    } catch (e) {
      print('ChatService: Error starting project: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Method to get a specific listing's details
  // This is used by ListingDetailsService, but might be needed if you fetch listing details directly in chat
  Future<Map<String, dynamic>> getListingDetails(int listingId) async {
    final url = Uri.parse('$_baseUrl/public_listing/get_listing_details.php?id=$listingId');
    try {
      final response = await http.get(url);
      final responseBody = json.decode(response.body);
      if (response.statusCode == 200 && responseBody['success']) {
        return responseBody;
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load listing details. Status: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // NEW METHOD: Fetches all conversations for a given user.
  Future<Map<String, dynamic>> getConversationsForUser({required int userId}) async {
    final url = Uri.parse('$_baseUrl/chat/get_conversations.php?user_id=$userId');
    print('ChatService: Fetching conversations for user ID: $userId from URL: $url');

    try {
      final response = await http.get(url);
      print('ChatService: Received status code (getConversationsForUser): ${response.statusCode}');
      print('ChatService: RAW RESPONSE BODY (getConversationsForUser): ${response.body}');

      if (response.body.isEmpty) {
        print('ChatService: Received empty response body for getConversationsForUser.');
        return {'success': false, 'message': 'Empty response from server for conversations. Check PHP logs.'};
      }

      final responseBody = json.decode(response.body);
      print('ChatService: Decoded JSON response (getConversationsForUser): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        List<ConversationPreview> conversations = (responseBody['conversations'] as List)
            .map((convJson) => ConversationPreview.fromJson(convJson as Map<String, dynamic>))
            .toList();
        return {'success': true, 'conversations': conversations};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load conversations.'};
      }
    } catch (e) {
      print('ChatService Error fetching conversations: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  /// Mark a job application as complete (for Lister).
  Future<Map<String, dynamic>> markJobAsComplete({
    required int applicationId,
    required int listerId,
    required int doerId,
    required String listingTitle,
  }) async {
    final url = Uri.parse('$_baseUrl/applications/mark_job_complete.php');
    print('ChatService: Marking job complete for application ID: $applicationId by Lister: $listerId with Doer: $doerId. Title: $listingTitle');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'lister_id': listerId,
          'doer_id': doerId,
          'listing_title': listingTitle,
        }),
      );

      final responseBody = json.decode(response.body);
      print('ChatService Mark Job Complete Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to mark job complete.'};
      }
    } catch (e) {
      print('ChatService Error marking job complete: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
