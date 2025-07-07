import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/balance.dart';
import 'package:hanapp/models/transaction.dart';

class BalanceService {
  Future<Map<String, dynamic>> getBalance(int userId) async {
    try {
      final uri = Uri.parse(ApiConfig.getBalanceEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        return {'success': true, 'balance': Balance.fromJson(responseBody['balance'])};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTransactions(int userId) async {
    try {
      final uri = Uri.parse(ApiConfig.getTransactionsEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        List<Transaction> transactions = (responseBody['transactions'] as List).map((json) => Transaction.fromJson(json)).toList();
        return {'success': true, 'transactions': transactions};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}