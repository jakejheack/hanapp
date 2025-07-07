import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/user.dart';

import '../utils/api_config.dart'; // Import your User model

class UserService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Fetches a user's profile details by their ID.
  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    final url = Uri.parse('$_baseUrl/profile/get_user_profile.php?user_id=$userId');
    print('UserService: Fetching user profile from URL: $url');

    try {
      final response = await http.get(url);
      print('UserService: Received status code (getUserProfile): ${response.statusCode}');
      print('UserService: RAW RESPONSE BODY (getUserProfile): ${response.body}');

      if (response.body.isEmpty) {
        print('UserService: Received empty response body for getUserProfile.');
        return {'success': false, 'message': 'Empty response from server for user profile. Check PHP logs.'};
      }

      final responseBody = json.decode(response.body);
      print('UserService: Decoded JSON response (getUserProfile): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'user': User.fromJson(responseBody['user'])};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load user profile.'};
      }
    } catch (e) {
      print('UserService Error fetching user profile: $e');
      return {'success': false, 'message': 'Network error: $e. Please check server logs.'};
    }
  }
}
