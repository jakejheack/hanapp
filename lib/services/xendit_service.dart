import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class XenditService {
  static const String _baseUrl = 'https://api.xendit.co';

  // Xendit API configuration
  // Only Secret Key is required for server-side operations
  static const String _secretKey = 'xnd_production_k5NqlGpmZlTPGEvBlYrk7a9ukwr8b2DzfQtEh3YThOcZazymwOlXwFT5ZEHIZm2'; // Replace with your actual secret key

  // Payment receiver configuration
  static const String _businessName = 'HanApp';
  // Note: Business email is optional for invoice creation
  static const String? _businessEmail = null; // No business email available

  static XenditService? _instance;
  static XenditService get instance => _instance ??= XenditService._();
  XenditService._();

  /// Create a payment invoice using only Secret Key
  Future<Map<String, dynamic>?> createInvoice({
    required double amount,
    required String paymentMethod,
    required String customerEmail,
    String? customerName,
    String? description,
  }) async {
    try {
      print('💳 Creating Xendit invoice for ₱${amount.toStringAsFixed(2)}');
      print('🏢 Business: $_businessName');
      print('👤 Customer: ${customerName ?? 'Customer'} ($customerEmail)');

      // Generate unique external ID with business prefix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final externalId = 'hanapp_payment_$timestamp';

      // Build invoice request body
      final requestBody = <String, dynamic>{
        'external_id': externalId,
        'amount': amount,
        'description': description ?? 'Payment to $_businessName via ${_getPaymentMethodName(paymentMethod)}',
        'invoice_duration': 86400, // 24 hours expiry
        'currency': 'PHP',

        // Customer information (email is required)
        'customer': {
          'given_names': customerName ?? 'Customer',
          'email': customerEmail,
        },

        // Notification preferences (only email since we have customer email)
        'customer_notification_preference': {
          'invoice_created': ['email'],
          'invoice_reminder': ['email'],
          'invoice_paid': ['email'],
          'invoice_expired': ['email'],
        },

        // Redirect URLs (you can customize these)
        'success_redirect_url': 'https://hanapp.com/payment/success',
        'failure_redirect_url': 'https://hanapp.com/payment/failed',

        // Invoice items
        'items': [
          {
            'name': '${_getPaymentMethodName(paymentMethod)} - $_businessName',
            'quantity': 1,
            'price': amount,
            'category': 'Service',
            'url': 'https://hanapp.com',
          }
        ],

        // Additional metadata for tracking
        'metadata': {
          'business_name': _businessName,
          'payment_method': paymentMethod,
          'customer_email': customerEmail,
          'created_at': DateTime.now().toIso8601String(),
        },
      };

      // Configure payment methods based on selection
      _configurePaymentMethods(requestBody, paymentMethod);

      print('📤 Sending request to Xendit API...');
      print('🔑 Using Secret Key authentication');

      final response = await http.post(
        Uri.parse('$_baseUrl/v2/invoices'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
          'Content-Type': 'application/json',
          'User-Agent': 'HanApp/1.0',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Xendit API Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ Invoice created successfully');
        print('🔗 Invoice URL: ${responseData['invoice_url']}');
        print('💰 Amount: ₱${responseData['amount']}');
        print('📅 Expires: ${responseData['expiry_date']}');
        
        return responseData;
      } else {
        print('❌ Xendit API Error: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
        
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 'Unknown error occurred';
          print('🚨 Error message: $errorMessage');
          throw Exception('Payment service error: $errorMessage');
        } catch (e) {
          print('❌ Failed to parse error response: $e');
          throw Exception('Payment service is temporarily unavailable. Please try again later.');
        }
      }
    } catch (e) {
      print('❌ Error creating invoice: $e');
      print('📱 Stack trace: ${StackTrace.current}');
      
      // Re-throw with user-friendly message
      if (e.toString().contains('Payment service error:')) {
        rethrow;
      } else {
        throw Exception('Unable to process payment. Please check your internet connection and try again.');
      }
    }
  }

  /// Configure payment methods for the invoice
  void _configurePaymentMethods(Map<String, dynamic> requestBody, String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'gcash':
        requestBody['payment_methods'] = ['GCASH'];
        break;
      case 'paymaya':
        requestBody['payment_methods'] = ['PAYMAYA'];
        break;
      case 'grabpay':
        requestBody['payment_methods'] = ['GRABPAY'];
        break;
      case 'bank_transfer':
        // Use generic bank transfer - let Xendit show available banks
        requestBody['payment_methods'] = ['BANK_TRANSFER'];
        break;
      case 'bpi':
        // BPI Direct Debit - CONFIRMED WORKING identifier
        requestBody['payment_methods'] = ['DD_BPI'];
        break;
      case 'bdo':
        // BDO not shown in your dashboard, but try standard identifier
        requestBody['payment_methods'] = ['BDO'];
        break;
      case 'metrobank':
        // Metrobank Online Banking
        requestBody['payment_methods'] = ['METROBANK'];
        break;
      case 'unionbank':
        // UBP Direct Debit - CONFIRMED WORKING identifier
        requestBody['payment_methods'] = ['DD_UBP'];
        break;
      case 'rcbc':
        // RCBC Direct Debit - CONFIRMED WORKING identifier
        requestBody['payment_methods'] = ['DD_RCBC'];
        break;
      case 'chinabank':
        // China Bank Direct Debit - CONFIRMED WORKING identifier
        requestBody['payment_methods'] = ['DD_CHINABANK'];
        break;
      case 'card':
        requestBody['payment_methods'] = ['CREDIT_CARD', 'DEBIT_CARD'];
        break;
      case 'ewallet':
        // Multiple e-wallet methods
        requestBody['payment_methods'] = ['GCASH', 'PAYMAYA'];
        break;
      default:
        // Allow all payment methods if not specified
        requestBody['payment_methods'] = ['GCASH', 'PAYMAYA', 'BANK_TRANSFER', 'CREDIT_CARD', 'DEBIT_CARD'];
    }

    print('💳 Configured payment methods: ${requestBody['payment_methods']}');
  }

  /// Launch payment URL in browser/webview
  Future<bool> launchPayment(String invoiceUrl) async {
    try {
      print('🚀 Attempting to launch payment URL: $invoiceUrl');

      // Validate URL format
      if (invoiceUrl.isEmpty) {
        print('❌ Empty invoice URL provided');
        return false;
      }

      if (!invoiceUrl.startsWith('http://') && !invoiceUrl.startsWith('https://')) {
        print('❌ Invalid URL format: $invoiceUrl');
        return false;
      }

      final uri = Uri.parse(invoiceUrl);
      print('🔗 Parsed URI: $uri');

      // Check if URL can be launched
      final canLaunch = await canLaunchUrl(uri);
      print('🔍 Can launch URL: $canLaunch');

      if (canLaunch) {
        print('🌐 Launching URL in external browser...');
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in browser
        );
        print('✅ URL launch result: $launched');
        return launched;
      } else {
        print('❌ Cannot launch payment URL with canLaunchUrl check');
        print('💡 Trying alternative launch modes without canLaunchUrl check...');

        // Try with platform default mode (most compatible)
        try {
          print('🔄 Trying platform default mode...');
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          print('✅ Launched with platform default mode');
          return true;
        } catch (e) {
          print('❌ Platform default mode failed: $e');
        }

        // Try with external application mode
        try {
          print('🔄 Trying external application mode...');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('✅ Launched with external application mode');
          return true;
        } catch (e) {
          print('❌ External application mode failed: $e');
        }

        // Try with in-app browser view
        try {
          print('🔄 Trying in-app browser view mode...');
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          print('✅ Launched with in-app browser view');
          return true;
        } catch (e) {
          print('❌ In-app browser view failed: $e');
        }

        print('❌ All launch modes failed');
        return false;
      }
    } catch (e) {
      print('❌ Error launching payment: $e');
      print('📱 Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Get payment status by invoice ID
  Future<Map<String, dynamic>?> getPaymentStatus(String invoiceId) async {
    try {
      print('🔍 Checking payment status for invoice: $invoiceId');

      final response = await http.get(
        Uri.parse('$_baseUrl/v2/invoices/$invoiceId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ Payment status retrieved: ${responseData['status']}');
        return responseData;
      } else {
        print('❌ Failed to get payment status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting payment status: $e');
      return null;
    }
  }

  /// Calculate payment processing fee
  double _calculateFee(double amount, String paymentMethod) {
    switch (paymentMethod) {
      case 'gcash':
      case 'paymaya':
        return amount * 0.025; // 2.5% for e-wallets
      case 'bank_transfer':
        return 15.0; // Fixed fee for bank transfers
      case 'card':
        return amount * 0.035 + 15.0; // 3.5% + ₱15 for cards
      default:
        return 0.0;
    }
  }

  /// Get user-friendly payment method name
  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'gcash':
        return 'GCash Payment';
      case 'paymaya':
        return 'PayMaya Payment';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'card':
        return 'Credit/Debit Card';
      default:
        return 'Payment';
    }
  }

  /// Validate Xendit configuration (only Secret Key needed)
  bool isConfigured() {
    final isValid = !_secretKey.contains('YOUR_XENDIT_SECRET_KEY_HERE') &&
                   _secretKey.isNotEmpty &&
                   _secretKey.startsWith('xnd_');

    print('🔍 Xendit Configuration Check:');
    print('   Secret Key configured: ${isValid ? '✅' : '❌'}');
    print('   Business Name: $_businessName');
    print('   Business Email: ${_businessEmail ?? 'Not provided (optional)'}');

    return isValid;
  }

  /// Get invoice status by invoice ID
  Future<Map<String, dynamic>?> getInvoiceStatus(String invoiceId) async {
    try {
      print('🔍 Checking invoice status for: $invoiceId');

      final url = Uri.parse('$_baseUrl/invoices/$invoiceId');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Invoice status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Invoice status retrieved: ${data['status']}');
        return data;
      } else {
        print('❌ Failed to get invoice status: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting invoice status: $e');
      return null;
    }
  }

  /// Get business information
  Map<String, dynamic> getBusinessInfo() {
    return {
      'name': _businessName,
      'email': _businessEmail,
      'has_email': _businessEmail != null,
      'configured': isConfigured(),
    };
  }
}
