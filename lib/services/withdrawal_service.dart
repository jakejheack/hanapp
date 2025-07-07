import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:hanapp/utils/api_config.dart'; // Ensure correct path
import 'package:hanapp/models/user.dart'; // To get user ID
import 'package:hanapp/models/withdrawal_request.dart'; // NEW: Import withdrawal request model

class WithdrawalService {
  // Fetches user's total profit and verification status
  Future<Map<String, dynamic>> getUserFinancialDetails(int userId) async {
    final url = Uri.parse('${ApiConfig.getUserFinancialDetailsEndpoint}?user_id=$userId');
    debugPrint('WithdrawalService: Fetching financial details from URL: $url');

    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      debugPrint('WithdrawalService: Financial Details Status Code: ${response.statusCode}');
      debugPrint('WithdrawalService: Financial Details Response Body: ${response.body}');

      if (response.statusCode == 200 && responseData['success']) {
        return {
          'success': true,
          'total_profit': (responseData['total_profit'] as num?)?.toDouble() ?? 0.0,
          'is_verified': (responseData['is_verified'] == 1 || responseData['is_verified'] == true),
        };
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch financial details.'};
      }
    } catch (e) {
      debugPrint('WithdrawalService: Error fetching financial details: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Submits a withdrawal request
  Future<Map<String, dynamic>> submitWithdrawal({
    required int userId,
    required double amount,
    required String method,
    required String accountDetails,
  }) async {
    final url = Uri.parse(ApiConfig.submitWithdrawalEndpoint);
    debugPrint('WithdrawalService: Submitting withdrawal request to URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'amount': amount,
          'method': method,
          'account_details': accountDetails,
        }),
      );
      final responseData = json.decode(response.body);

      debugPrint('WithdrawalService: Submit Withdrawal Status Code: ${response.statusCode}');
      debugPrint('WithdrawalService: Submit Withdrawal Response Body: ${response.body}');

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'message': responseData['message']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to submit withdrawal request.'};
      }
    } catch (e) {
      debugPrint('WithdrawalService: Error submitting withdrawal: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Fetches withdrawal request history for a user
  Future<Map<String, dynamic>> getWithdrawalHistory(int userId) async {
    final url = Uri.parse('${ApiConfig.getWithdrawalHistoryEndpoint}?user_id=$userId');
    debugPrint('WithdrawalService: Fetching withdrawal history from URL: $url');

    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      debugPrint('WithdrawalService: Withdrawal History Status Code: ${response.statusCode}');
      debugPrint('WithdrawalService: Withdrawal History Response Body: ${response.body}');

      if (response.statusCode == 200 && responseData['success']) {
        List<WithdrawalRequest> withdrawals = (responseData['withdrawals'] as List)
            .map((json) => WithdrawalRequest.fromJson(json))
            .toList();
        
        return {
          'success': true,
          'withdrawals': withdrawals,
          'count': withdrawals.length,
        };
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch withdrawal history.'};
      }
    } catch (e) {
      debugPrint('WithdrawalService: Error fetching withdrawal history: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // DEBUG: Test different endpoints to see which ones work
  Future<Map<String, dynamic>> testEndpoints() async {
    final endpoints = [
      '${ApiConfig.baseUrl}/finance/test_endpoint.php',
      '${ApiConfig.baseUrl}/finance/get_withdrawal_history.php?user_id=47',
      '${ApiConfig.baseUrl}/finance/get_withdrawal_history_simple.php?user_id=47',
      '${ApiConfig.baseUrl}/user/get_user_financial_details.php?user_id=47',
    ];

    Map<String, dynamic> results = {};

    for (String url in endpoints) {
      debugPrint('WithdrawalService: Testing endpoint: $url');
      
      try {
        final response = await http.get(Uri.parse(url));
        final responseData = json.decode(response.body);
        
        results[url] = {
          'status_code': response.statusCode,
          'success': responseData['success'] ?? false,
          'message': responseData['message'] ?? 'No message',
          'body_preview': response.body.substring(0, response.body.length > 200 ? 200 : response.body.length),
        };
      } catch (e) {
        results[url] = {
          'error': e.toString(),
          'body_preview': 'Error occurred',
        };
      }
    }

    return results;
  }
}
