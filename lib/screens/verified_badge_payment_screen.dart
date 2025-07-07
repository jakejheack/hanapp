import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'dart:async'; // For Timer
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/services/payment_service.dart';
import 'package:hanapp/services/verification_service.dart'; // To refresh user status
import 'package:hanapp/services/xendit_service.dart'; // For Xendit integration

class VerifiedBadgePaymentScreen extends StatefulWidget {
  const VerifiedBadgePaymentScreen({super.key});

  @override
  State<VerifiedBadgePaymentScreen> createState() => _VerifiedBadgePaymentScreenState();
}

class _VerifiedBadgePaymentScreenState extends State<VerifiedBadgePaymentScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController(); // MM/YY
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _cardHolderNameController = TextEditingController();

  String? _selectedPaymentMethod; // 'card', 'bank_transfer', 'gcash', 'paymaya', 'grabpay'
  String? _selectedBank; // For bank transfer
  bool _isSubmitting = false;
  User? _currentUser;
  final PaymentService _paymentService = PaymentService();
  final VerificationService _verificationService = VerificationService(); // To refresh badge status

  // Track current payment session
  String? _currentInvoiceId;
  String? _currentExternalId;
  Timer? _paymentCheckTimer;

  // Bank options for bank transfer
  final List<Map<String, String>> _bankOptions = [
    {'name': 'BPI', 'value': 'bpi'},
    {'name': 'BDO', 'value': 'bdo'},
    {'name': 'Metrobank', 'value': 'metrobank'},
    {'name': 'Security Bank', 'value': 'security_bank'},
    {'name': 'RCBC', 'value': 'rcbc'},
    {'name': 'UnionBank', 'value': 'unionbank'},
    {'name': 'PNB', 'value': 'pnb'},
    {'name': 'Landbank', 'value': 'landbank'},
  ];

  @override
  void initState() { // initState should NOT be async.
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for app lifecycle
    _loadCurrentUser(); // Call a separate async method
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When user returns to the app (e.g., from payment browser)
    if (state == AppLifecycleState.resumed) {
      _checkPaymentStatus();
    }
  }

  // Method to asynchronously load current user and pre-fill email
  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    setState(() {
      _currentUser = user;
      if (_currentUser != null && _currentUser!.email.isNotEmpty) {
        _emailController.text = _currentUser!.email;
      }
    });
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _paymentCheckTimer?.cancel(); // Cancel timer if active
    _emailController.dispose();
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvcController.dispose();
    _cardHolderNameController.dispose();
    super.dispose();
  }

  // Check payment status when user returns from browser
  Future<void> _checkPaymentStatus() async {
    // Only check if we have an active payment session
    if (_currentInvoiceId == null || _currentUser == null) {
      return;
    }

    print('🔍 Manual payment status check for invoice: $_currentInvoiceId');

    // Show loading while checking payment status
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Checking payment status...'),
          ],
        ),
      ),
    );

    try {
      // Check payment status via Xendit API
      final paymentStatus = await XenditService.instance.getInvoiceStatus(_currentInvoiceId!);

      // Hide loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (paymentStatus != null) {
        final status = paymentStatus['status'];
        print('💳 Manual payment status: $status');

        if (status == 'PAID' || status == 'SETTLED') {
          // Payment successful - stop timer and process
          _paymentCheckTimer?.cancel();
          await _handleSuccessfulPayment();
        } else if (status == 'EXPIRED' || status == 'FAILED') {
          // Payment failed - stop timer and notify
          _paymentCheckTimer?.cancel();
          _handleFailedPayment();
        } else {
          // Payment still pending
          _showSnackBar('Payment is still pending. Please complete your payment.');
        }
      } else {
        _showSnackBar('Unable to verify payment status. Please try again.', isError: true);
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('❌ Error checking payment status: $e');
      _showSnackBar('Error checking payment status. Please try again.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _subscribe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in. Cannot process payment.', isError: true);
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method', isError: true);
      return;
    }

    if (_selectedPaymentMethod == 'bank_transfer' && _selectedBank == null) {
      _showSnackBar('Please select a bank for bank transfer', isError: true);
      return;
    }

    final double amount = 299.0; // P299 for monthly subscription

    // Check if Xendit is configured
    if (!XenditService.instance.isConfigured()) {
      _showConfigurationDialog(amount);
      return;
    }

    // Show loading
    _showLoadingDialog();

    try {
      // Determine the actual payment method to use
      String actualPaymentMethod = _selectedPaymentMethod!;
      if (_selectedPaymentMethod == 'bank_transfer' && _selectedBank != null) {
        actualPaymentMethod = _selectedBank!;
      }

      // Create Xendit invoice
      final invoice = await XenditService.instance.createInvoice(
        amount: amount,
        paymentMethod: actualPaymentMethod,
        customerEmail: _emailController.text.trim(),
        customerName: _currentUser!.fullName,
        description: 'Verified Badge Subscription - ${_getPaymentMethodName(actualPaymentMethod)}',
      );

      // Hide loading
      Navigator.of(context).pop();

      if (invoice != null) {
        final invoiceUrl = invoice['invoice_url'];
        final invoiceId = invoice['id'];
        final externalId = invoice['external_id'];

        // Store invoice details for status checking
        setState(() {
          _currentInvoiceId = invoiceId;
          _currentExternalId = externalId;
        });

        if (invoiceUrl != null && invoiceUrl.toString().isNotEmpty) {
          print('🚀 Attempting to launch payment URL...');
          print('📋 Invoice ID: $invoiceId');
          print('🔗 External ID: $externalId');

          // Launch payment URL
          final launched = await XenditService.instance.launchPayment(invoiceUrl.toString());

          if (launched) {
            _showSnackBar('Payment page opened. Complete your payment in the browser.');

            // Start a timer to periodically check payment status
            _startPaymentStatusTimer();
          } else {
            print('❌ Failed to launch payment URL');
            // Show the URL to user as fallback
            _showPaymentUrlDialog(invoiceUrl.toString());
          }
        } else {
          print('❌ No invoice URL in response: $invoice');
          _showSnackBar('Invalid payment URL received from payment service.', isError: true);
        }
      } else {
        _showSnackBar('Failed to create payment invoice. Please try again.', isError: true);
      }
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      print('❌ Payment error: $e');
      _showSnackBar('Error processing payment: $e', isError: true);
    }
  }

  // Start timer to periodically check payment status
  void _startPaymentStatusTimer() {
    // Cancel any existing timer
    _paymentCheckTimer?.cancel();

    // Check payment status every 30 seconds for up to 15 minutes
    int checkCount = 0;
    const maxChecks = 30; // 30 checks * 30 seconds = 15 minutes

    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      checkCount++;
      print('🕐 Payment status check #$checkCount');

      if (checkCount >= maxChecks) {
        // Payment timeout after 15 minutes
        timer.cancel();
        _handlePaymentTimeout();
        return;
      }

      if (_currentInvoiceId != null) {
        await _checkPaymentStatusSilently();
      } else {
        // No active payment session, cancel timer
        timer.cancel();
      }
    });
  }

  // Handle payment timeout
  void _handlePaymentTimeout() {
    print('⏰ Payment timeout reached');
    _showSnackBar('Payment session expired. Please try again.', isError: true);

    // Clear payment session
    setState(() {
      _currentInvoiceId = null;
      _currentExternalId = null;
    });
  }

  // Check payment status silently (without showing loading dialog)
  Future<void> _checkPaymentStatusSilently() async {
    if (_currentInvoiceId == null || _currentUser == null) {
      return;
    }

    try {
      final paymentStatus = await XenditService.instance.getInvoiceStatus(_currentInvoiceId!);

      if (paymentStatus != null) {
        final status = paymentStatus['status'];
        print('💳 Silent payment status check: $status');

        if (status == 'PAID' || status == 'SETTLED') {
          // Payment successful - stop timer and process
          _paymentCheckTimer?.cancel();
          await _handleSuccessfulPayment();
        } else if (status == 'EXPIRED' || status == 'FAILED') {
          // Payment failed - stop timer and notify user
          _paymentCheckTimer?.cancel();
          _handleFailedPayment();
        }
        // If still pending, continue checking
      }
    } catch (e) {
      print('❌ Error in silent payment status check: $e');
      // Continue checking on error
    }
  }

  // Handle successful payment
  Future<void> _handleSuccessfulPayment() async {
    _showSnackBar('Payment confirmed! Processing your verification...');

    try {
      await _verificationService.acquireVerifiedBadge(userId: _currentUser!.id!);
      await AuthService.fetchAndSetUser();
      _showSnackBar('Verified badge activated successfully!');

      // Clear payment session
      setState(() {
        _currentInvoiceId = null;
        _currentExternalId = null;
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnackBar('Error activating verified badge: $e', isError: true);
    }
  }

  // Handle failed payment
  void _handleFailedPayment() {
    _showSnackBar('Payment was not completed. Please try again.', isError: true);

    // Clear payment session
    setState(() {
      _currentInvoiceId = null;
      _currentExternalId = null;
    });
  }

  // Helper method to get payment method display name
  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'gcash':
        return 'GCash E-Wallet';
      case 'grabpay':
        return 'GrabPay E-Wallet';
      case 'paymaya':
        return 'Maya E-Wallet';
      case 'card':
        return 'Credit/Debit Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'bpi':
        return 'BPI Bank Transfer';
      case 'bdo':
        return 'BDO Bank Transfer';
      case 'metrobank':
        return 'Metrobank Transfer';
      case 'security_bank':
        return 'Security Bank Transfer';
      case 'rcbc':
        return 'RCBC Bank Transfer';
      case 'unionbank':
        return 'UnionBank Transfer';
      case 'pnb':
        return 'PNB Bank Transfer';
      case 'landbank':
        return 'Landbank Transfer';
      default:
        return method.toUpperCase();
    }
  }

  // Show loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Processing payment...'),
          ],
        ),
      ),
    );
  }

  // Show configuration dialog
  void _showConfigurationDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Service Configuration'),
        content: const Text(
          'Payment service is not properly configured. This is a demo version.\n\n'
          'In a real app, you would need to:\n'
          '• Set up a Xendit account\n'
          '• Configure API keys\n'
          '• Set up webhooks for payment notifications',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDemoPaymentDialog(amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Demo'),
          ),
        ],
      ),
    );
  }

  // Show demo payment dialog
  void _showDemoPaymentDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demo Payment'),
        content: Text(
          'Demo payment of ₱${amount.toStringAsFixed(2)} for Verified Badge Subscription.\n\n'
          'In a real app, this would redirect to the actual payment gateway.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _showSnackBar('Demo payment completed successfully!');
              // For demo purposes, we'll simulate the complete flow
              // In a real app, this would be handled by payment webhooks
              await _verificationService.acquireVerifiedBadge(userId: _currentUser!.id!);
              await AuthService.fetchAndSetUser();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Demo Payment'),
          ),
        ],
      ),
    );
  }

  // Show payment URL dialog as fallback
  void _showPaymentUrlDialog(String paymentUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to open payment page automatically. Please copy the URL below:'),
            const SizedBox(height: 16),
            SelectableText(
              paymentUrl,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Try to launch again
              Navigator.of(context).pop();
              final launched = await XenditService.instance.launchPayment(paymentUrl);
              if (launched) {
                _showSnackBar('Payment page opened successfully!');
              } else {
                _showSnackBar('Still unable to open payment page. Please copy the URL manually.', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Build payment option widget
  Widget _buildPaymentOption(String title, String value) {
    final isSelected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
          if (value != 'bank_transfer') {
            _selectedBank = null; // Clear bank selection for non-bank transfers
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Constants.primaryColor : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? Constants.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Constants.primaryColor : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Constants.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // Build divider
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 20,
      endIndent: 20,
    );
  }

  // Build bank transfer dropdown
  Widget _buildBankTransferDropdown() {
    final isSelected = _selectedPaymentMethod == 'bank_transfer';

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = 'bank_transfer';
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Constants.primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? Constants.primaryColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Bank Transfer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Constants.primaryColor : Colors.black87,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Constants.primaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (isSelected)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: DropdownButtonFormField<String>(
              value: _selectedBank,
              hint: const Text('Select Bank'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _bankOptions.map((bank) {
                return DropdownMenuItem<String>(
                  value: bank['value'],
                  child: Text(bank['name']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBank = value;
                });
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verified Badge'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                      ),
                      const Divider(height: 20, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Verified Badge\nSubscription (Monthly)',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                          ),
                          const Text(
                            'P299',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                          ),
                          Text(
                            'P299',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Enter Email
              const Text(
                'Enter Your Email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined, color: Constants.primaryColor),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Payment Methods
              const Text(
                'Payment Methods',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 16),

              // Payment Methods Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildPaymentOption('GCash E-Wallet', 'gcash'),
                    _buildDivider(),
                    _buildPaymentOption('GrabPay E-Wallet', 'grabpay'),
                    _buildDivider(),
                    _buildPaymentOption('Maya E-Wallet', 'paymaya'),
                    _buildDivider(),
                    _buildPaymentOption('Credit/Debit Card', 'card'),
                    _buildDivider(),
                    _buildBankTransferDropdown(),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Proceed Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedPaymentMethod != null ? _subscribe : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Proceed to Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Security Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your payment is secured by Xendit with bank-level encryption',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Formatter for Card Number (adds spaces)
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  // FIXED: Corrected 'TextedingValue' to 'TextEditingValue'
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = newValue.text.replaceAll(RegExp(r'\s+'), ''); // Remove existing spaces
    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != newText.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// Custom Formatter for Expiry Date (MM/YY)
class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  // FIXED: Corrected 'TextedingValue' to 'TextEditingValue'
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var newText = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && newText.length > 2) {
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
