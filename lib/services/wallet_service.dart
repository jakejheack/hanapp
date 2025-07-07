import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/transaction.dart';

import '../utils/api_config.dart';

class WalletService {
  final String _baseUrl = ApiConfig.baseUrl; // Ensure this is your Hostinger URL

  /// Fetches the user's current wallet balance.
  Future<Map<String, dynamic>> getWalletBalance({required int userId}) async {
    final url = Uri.parse('$_baseUrl/api/wallet/get_user_wallet_balance.php?user_id=$userId');
    print('WalletService: Fetching balance for user $userId from $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('WalletService Get Balance Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        return {'success': true, 'balance': double.parse(decodedResponse['balance'].toString())};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch balance.'};
      }
    } catch (e) {
      print('WalletService Error fetching balance: $e');
      return {'success': false, 'message': 'Network error: $e'}; // This is the error seen in your screenshot
    }
  }

  /// Initiates a cash-in payment using Xendit (creates an invoice).
  /// This will return a redirect URL if successful. Balance update happens via webhook.
  Future<Map<String, dynamic>> initiateCashIn({
    required int userId,
    required double amount,
    required String paymentMethod,
    String? userEmail,
    String? userFullName,
    String? contactNumber, // NEW: Optional contact number
  }) async {
    final url = Uri.parse('$_baseUrl/api/wallet/initiate_xendit_payment.php');
    print('WalletService: Initiating cash in for user $userId, amount $amount, method $paymentMethod to $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'amount': amount,
          'payment_method': paymentMethod,
          'user_email': userEmail,
          'user_full_name': userFullName,
          'contact_number': contactNumber, // NEW: Pass contact number
        }),
      );
      final decodedResponse = json.decode(response.body);

      print('WalletService Initiate Cash In Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        return {
          'success': true,
          'message': decodedResponse['message'],
          'redirect_url': decodedResponse['redirect_url'],
          'xendit_invoice_id': decodedResponse['xendit_invoice_id'],
        };
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to initiate cash in.'};
      }
    } catch (e) {
      print('WalletService Error initiating cash in: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetches the user's transaction history.
  Future<Map<String, dynamic>> getTransactionHistory({required int userId}) async {
    final url = Uri.parse('$_baseUrl/api/wallet/get_transaction_history.php?user_id=$userId');
    print('WalletService: Fetching transactions for user $userId from $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('WalletService Get Transactions Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        List<Transaction> transactions = (decodedResponse['transactions'] as List)
            .map((txnJson) => Transaction.fromJson(txnJson))
            .toList();
        return {'success': true, 'transactions': transactions};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch transaction history.'};
      }
    } catch (e) {
      print('WalletService Error fetching transaction history: $e');
      return {'success': false, 'message': 'Network error: $e'}; // This is the error seen in your screenshot
    }
  }
}
