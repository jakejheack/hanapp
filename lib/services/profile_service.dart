import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/user.dart';

import '../utils/api_config.dart'; // Ensure correct User model import

class ProfileService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Fetches a user's profile details from the backend.
  /// Includes basic user information, and aggregated rating/review counts.
  ///
  /// [userId]: The ID of the user whose profile is to be fetched.
  /// Returns a Map indicating success/failure and the User object or error message.
  Future<Map<String, dynamic>> getUserProfile({required int userId}) async {
    final url = Uri.parse('$_baseUrl/profile/get_user_profile.php?user_id=$userId');
    print('ProfileService: Fetching user profile from URL: $url'); // Debug log

    try {
      final response = await http.get(url);
      print('ProfileService: Received status code: ${response.statusCode}'); // Debug log
      print('ProfileService: Received response body length: ${response.body.length}'); // Debug log
      print('ProfileService: RAW RESPONSE BODY for profile: ${response.body}'); // Raw body for debugging

      // Check if response body is empty before attempting to decode
      if (response.body.isEmpty) {
        print('ProfileService: Received empty response body for getUserProfile. Returning failure.');
        return {'success': false, 'message': 'Empty response from server for profile. Check server logs.'};
      }

      final responseBody = json.decode(response.body); // Attempt to decode JSON
      print('ProfileService: Decoded JSON response for profile: $responseBody'); // Decoded response

      if (response.statusCode == 200 && responseBody['success']) {
        // Parse the user object from the 'user' key in the JSON response.
        return {
          'success': true,
          'user': User.fromJson(responseBody['user'] as Map<String, dynamic>),
        };
      } else {
        // Server returned an error, or 'success' was false
        print('ProfileService: Server returned success: false or unexpected status: ${responseBody['message']}');
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load profile details from server.'};
      }
    } catch (e) {
      // Catch any network errors or JSON decoding errors
      print('ProfileService Error fetching user profile: $e. This usually means invalid JSON or network issue.');
      return {'success': false, 'message': 'Network error: $e. Please check server logs for PHP errors.'};
    }
  }

// You would add other profile-related methods here, such as updateProfile, etc.
}
