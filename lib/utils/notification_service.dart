import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/notification.dart'; // NEW

class NotificationService {
  Future<Map<String, dynamic>> getNotifications(int userId) async {
    try {
      // Removed token retrieval
      final uri = Uri.parse(ApiConfig.getNotificationsEndpoint).replace(
        queryParameters: {'user_id': userId.toString()},
      );
      final response = await http.get(
        uri,
        // Removed headers
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        List<AppNotification> notifications = (responseBody['notifications'] as List)
            .map((json) => AppNotification.fromJson(json))
            .toList();
        return {'success': true, 'notifications': notifications};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      // Removed token retrieval
      final response = await http.post(
        Uri.parse(ApiConfig.markNotificationAsReadEndpoint),
        headers: {
          'Content-Type': 'application/json',
          // Removed 'Authorization'
        },
        body: jsonEncode({'notification_id': notificationId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}