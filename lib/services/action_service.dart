import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;

import '../utils/api_config.dart';

class ActionService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Submits a report against a user.
  Future<Map<String, dynamic>> reportUser({
    required int reporterUserId,
    required int reportedUserId,
    int? listingId,
    int? applicationId,
    required String reportReason,
    String? reportDetails,
  }) async {
    final url = Uri.parse('$_baseUrl/actions/report_user.php');
    print('ActionService: Submitting report to URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'reporter_user_id': reporterUserId,
          'reported_user_id': reportedUserId,
          'listing_id': listingId,
          'application_id': applicationId,
          'report_reason': reportReason,
          'report_details': reportDetails,
        }),
      );

      final responseBody = json.decode(response.body);
      print('ActionService Report User Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to submit report.'};
      }
    } catch (e) {
      print('ActionService Error reporting user: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Blocks a user.
  Future<Map<String, dynamic>> blockUser({
    required int userId,
    required int blockedUserId,

  }) async {
    final url = Uri.parse('$_baseUrl/actions/block_user.php');
    print('ActionService: Blocking user at URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'blocked_user_id': blockedUserId,

        }),
      );

      final responseBody = json.decode(response.body);
      print('ActionService Block User Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to block user.'};
      }
    } catch (e) {
      print('ActionService Error blocking user: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Checks if a target user is blocked by the current user.
  Future<Map<String, dynamic>> getBlockedStatus({
    required int currentUserId,
    required int targetUserId,
  }) async {
    final url = Uri.parse('$_baseUrl/actions/get_blocked_status.php?current_user_id=$currentUserId&target_user_id=$targetUserId');
    print('ActionService: Checking blocked status from URL: $url');

    try {
      final response = await http.get(url);
      final responseBody = json.decode(response.body);
      print('ActionService Get Blocked Status Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'is_blocked': responseBody['is_blocked']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to get blocked status.'};
      }
    } catch (e) {
      print('ActionService Error getting blocked status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Unblocks a user.
  /// NOTE: This endpoint is not created yet, you would need to create `unblock_user.php`
  Future<Map<String, dynamic>> unblockUser({
    required int userId,
    required int blockedUserId,

  }) async {
    final url = Uri.parse('$_baseUrl/actions/unblock_user.php'); // You need to create this PHP file
    print('ActionService: Unblocking user at URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'blocked_user_id': blockedUserId,

        }),
      );

      final responseBody = json.decode(response.body);
      print('ActionService Unblock User Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to unblock user.'};
      }
    } catch (e) {
      print('ActionService Error unblocking user: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
