import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hanapp/utils/api_config.dart';

class PaymentService {
  Future<Map<String, dynamic>> createXenditPayment({
    required int userId,
    required double amount,
    required String paymentMethod,
    String? userEmail,
    String? userFullName,
    String? mobileNumber,
  }) async {
    final url = Uri.parse(ApiConfig.createXenditPaymentEndpoint);
    debugPrint('PaymentService: Creating Xendit payment request for user $userId, amount $amount, method $paymentMethod');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // No 'Authorization' header needed
        body: json.encode({
          'user_id': userId, // Pass user ID directly for backend authorization
          'amount': amount,
          'payment_method': paymentMethod,
          'user_email': userEmail,
          'user_full_name': userFullName,
          'mobile_number': mobileNumber,
        }),
      );
      final responseData = json.decode(response.body);
      debugPrint('PaymentService: Create Xendit Payment Response: $responseData');

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'payment_details': responseData['payment_details']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to create payment request.'};
      }
    } catch (e) {
      debugPrint('PaymentService: Error creating Xendit payment: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTransactionHistory(int userId) async {
    final url = Uri.parse('${ApiConfig.getUserFinancialDetailsEndpoint}?user_id=$userId');
    debugPrint('PaymentService: Fetching transaction history for user $userId');

    try {
      final response = await http.get(url); // No 'Authorization' header needed
      final responseData = json.decode(response.body);
      debugPrint('PaymentService: Get Transaction History Response: $responseData');

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'transactions': responseData['transaction_history'] ?? []};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch transaction history.'};
      }
    } catch (e) {
      debugPrint('PaymentService: Error fetching transaction history: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  final String _baseUrl = ApiConfig.baseUrl;

  /// Processes payment via your backend, which then interacts with Xendit.
  /// IMPORTANT: This example sends raw card details to YOUR backend.
  /// For PCI compliance, you should use Xendit's client-side SDKs for card tokenization.
  Future<Map<String, dynamic>> processXenditPayment({
    required int userId,
    required double amount,
    required String email,
    required String paymentMethod, // 'card', 'bank_transfer', 'gcash', 'paymaya'
    String? cardNumber,
    String? expiryMonth,
    String? expiryYear,
    String? cvc,
    String? cardHolderName,
  }) async {
    final url = Uri.parse('$_baseUrl/payment/process_xendit_payment.php');
    print('PaymentService: Processing Xendit payment for user: $userId, method: $paymentMethod');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'amount': amount,
          'email': email,
          'payment_method': paymentMethod,
          'card_number': cardNumber,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'cvc': cvc,
          'card_holder_name': cardHolderName,
        }),
      );

      final decodedResponse = json.decode(response.body);
      print('PaymentService Process Payment Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        return {'success': true, 'message': decodedResponse['message']};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Payment failed.'};
      }
    } catch (e) {
      print('PaymentService Error processing Xendit payment: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
