import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/notification_model.dart';

import '../utils/api_config.dart';

class NotificationService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Fetches notifications for a given user.
  Future<Map<String, dynamic>> getNotifications({required int userId}) async {
    final url = Uri.parse('$_baseUrl/notifications/get_notifications.php?user_id=$userId');
    print('NotificationService: Fetching notifications from URL: $url');

    try {
      final response = await http.get(url);
      print('NotificationService: Received status code: ${response.statusCode}');
      print('NotificationService: Raw response body: ${response.body}');

      if (response.body.isEmpty) {
        print('NotificationService: Empty response body. Returning failure.');
        return {'success': false, 'message': 'Empty response from server. Check PHP logs for get_notifications.php.'};
      }

      final responseBody = json.decode(response.body);
      print('NotificationService: Decoded JSON: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        List<NotificationModel> notifications = (responseBody['notifications'] as List)
            .map((notifJson) => NotificationModel.fromJson(notifJson as Map<String, dynamic>))
            .toList();
        return {'success': true, 'notifications': notifications};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load notifications.'};
      }
    } catch (e) {
      print('NotificationService Error fetching notifications: $e');
      return {'success': false, 'message': 'Network error: $e. Check server logs.'};
    }
  }

  /// Marks a specific notification as read.
  Future<Map<String, dynamic>> markNotificationAsRead({required int notificationId}) async {
    final url = Uri.parse('$_baseUrl/notifications/mark_read.php');
    print('NotificationService: Marking notification $notificationId as read.');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'notification_id': notificationId}),
      );

      final responseBody = json.decode(response.body);
      print('NotificationService Mark As Read Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to mark as read.'};
      }
    } catch (e) {
      print('NotificationService Error marking as read: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetches doer notifications for a given user.
  Future<Map<String, dynamic>> getDoerNotifications({required int userId}) async {
    final url = Uri.parse(ApiConfig.getDoerNotificationsEndpoint).replace(queryParameters: {'user_id': userId.toString()});
    print('NotificationService: Fetching doer notifications from URL: $url');

    try {
      final response = await http.get(url);
      print('NotificationService: Received status code: \\${response.statusCode}');
      print('NotificationService: Raw response body: \\${response.body}');

      if (response.body.isEmpty) {
        print('NotificationService: Empty response body. Returning failure.');
        return {'success': false, 'message': 'Empty response from server. Check PHP logs for get_doer_notifications.php.'};
      }

      final responseBody = json.decode(response.body);
      print('NotificationService: Decoded JSON: \\${responseBody}');

      if (response.statusCode == 200 && responseBody['success']) {
        List<NotificationModel> notifications = (responseBody['notifications'] as List)
            .map((notifJson) => NotificationModel.fromJson(notifJson as Map<String, dynamic>))
            .toList();
        return {'success': true, 'notifications': notifications};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load doer notifications.'};
      }
    } catch (e) {
      print('NotificationService Error fetching doer notifications: $e');
      return {'success': false, 'message': 'Network error: $e. Check server logs.'};
    }
  }

  /// Creates a new doer notification
  Future<Map<String, dynamic>> createDoerNotification({
    required int userId,
    int? senderId,
    required String type,
    required String title,
    required String content,
    int? associatedId,
    int? conversationId,
    int? conversationListerId,
    int? conversationDoerId,
    String? relatedListingTitle,
    int? listingId,
    String? listingType,
    int? listerId,
    String? listerName,
  }) async {
    final url = Uri.parse(ApiConfig.createDoerNotificationEndpoint);
    print('NotificationService: Creating doer notification at URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'sender_id': senderId,
          'type': type,
          'title': title,
          'content': content,
          'associated_id': associatedId,
          'conversation_id_for_chat_nav': conversationId,
          'conversation_lister_id': conversationListerId,
          'conversation_doer_id': conversationDoerId,
          'related_listing_title': relatedListingTitle,
          'listing_id': listingId,
          'listing_type': listingType,
          'lister_id': listerId,
          'lister_name': listerName,
        }),
      );

      final responseBody = json.decode(response.body);
      print('NotificationService Create Doer Notification Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'notification_id': responseBody['notification_id']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to create notification.'};
      }
    } catch (e) {
      print('NotificationService Error creating doer notification: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Gets the count of unread notifications for a doer
  Future<Map<String, dynamic>> getUnreadCount({required int userId}) async {
    final url = Uri.parse(ApiConfig.getUnreadCountEndpoint).replace(queryParameters: {'user_id': userId.toString()});
    print('NotificationService: Getting unread count from URL: $url');

    try {
      final response = await http.get(url);
      print('NotificationService: Unread count response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success']) {
          return {'success': true, 'unread_count': responseBody['unread_count']};
        } else {
          return {'success': false, 'message': responseBody['message'] ?? 'Failed to get unread count.'};
        }
      } else {
        return {'success': false, 'message': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      print('NotificationService Error getting unread count: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Marks a doer notification as read
  Future<Map<String, dynamic>> markDoerNotificationAsRead({required int notificationId}) async {
    final url = Uri.parse('$_baseUrl/notifications/mark_doer_read.php');
    print('NotificationService: Marking doer notification $notificationId as read.');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'notification_id': notificationId}),
      );

      final responseBody = json.decode(response.body);
      print('NotificationService Mark Doer As Read Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to mark as read.'};
      }
    } catch (e) {
      print('NotificationService Error marking doer notification as read: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
