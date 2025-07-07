import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/models/app_setting.dart';
import 'package:hanapp/utils/constants.dart' as Constants;

import '../utils/api_config.dart';

class SettingService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Fetches application setting content by its key name (e.g., 'terms_and_conditions', 'privacy_policy').
  Future<Map<String, dynamic>> getAppSetting({required String category}) async {
    final url = Uri.parse('$_baseUrl/settings/get_app_setting_by_key.php?category=$category');
    print('SettingService: Fetching setting for key "$category" from $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('SettingService Get Setting Response ($category): ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        return {'success': true, 'data': AppSetting.fromJson(decodedResponse['data'])};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch content for key "$category".'};
      }
    } catch (e) {
      print('SettingService Error fetching setting for key "$category": $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // You can still keep a specific helper for T&C if you want:
  Future<Map<String, dynamic>> getTermsAndConditions() async {
    return getAppSetting(category: 'terms_and_conditions');
  }

  // NEW: Helper for Privacy Policy
  Future<Map<String, dynamic>> getPrivacyPolicy() async {
    return getAppSetting(category: 'privacy_policy');
  }
} 