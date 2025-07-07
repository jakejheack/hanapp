import 'package:flutter/material.dart';
import 'package:hanapp/services/xendit_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:webview_flutter/webview_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final User user;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.user,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPaymentMethod;
  String? _selectedBank; // For bank transfer dropdown
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Make Payment'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Constants.primaryColor, Constants.primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Constants.primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Amount to Pay',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: '₱ ',
                      prefixStyle: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Payment Methods
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
                onPressed: _selectedPaymentMethod != null ? _processPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
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
    );
  }

  Widget _buildPaymentOption(String title, String value) {
    final isSelected = _selectedPaymentMethod == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
          if (value != 'bank_transfer') {
            _selectedBank = null; // Clear bank selection for non-bank methods
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Constants.primaryColor : Colors.grey.shade300,
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
                Icons.arrow_forward_ios,
                color: Constants.primaryColor,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankTransferDropdown() {
    final isSelected = _selectedPaymentMethod == 'bank_transfer';
    
    // List of working banks only
    final workingBanks = [
      {'id': 'bpi', 'name': 'BPI Direct Debit', 'icon': '🏦'},
      {'id': 'chinabank', 'name': 'China Bank Direct Debit', 'icon': '🏦'},
      {'id': 'rcbc', 'name': 'RCBC Direct Debit', 'icon': '🏦'},
      {'id': 'unionbank', 'name': 'UBP Direct Debit', 'icon': '🏦'},
    ];

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_selectedPaymentMethod == 'bank_transfer') {
                _selectedPaymentMethod = null;
                _selectedBank = null;
              } else {
                _selectedPaymentMethod = 'bank_transfer';
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Constants.primaryColor : Colors.grey.shade300,
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
                Icon(
                  isSelected ? Icons.expand_less : Icons.expand_more,
                  color: isSelected ? Constants.primaryColor : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (isSelected) ...[
          Container(
            margin: const EdgeInsets.only(left: 60, right: 20, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBank,
                hint: const Text('Select your bank'),
                items: workingBanks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank['id'] as String,
                    child: Row(
                      children: [
                        Text(bank['icon'] as String, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(bank['name'] as String)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedBank = value;
                  });
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: Colors.grey.shade200,
    );
  }

  void _processPayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showErrorMessage('Please enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showErrorMessage('Please enter a valid amount');
      return;
    }

    if (_selectedPaymentMethod == null) {
      _showErrorMessage('Please select a payment method');
      return;
    }

    if (_selectedPaymentMethod == 'bank_transfer' && _selectedBank == null) {
      _showErrorMessage('Please select a bank for bank transfer');
      return;
    }

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
        customerEmail: widget.user.email,
        customerName: widget.user.fullName,
        description: 'Payment via ${_getPaymentMethodName(actualPaymentMethod)}',
      );

      // Hide loading
      Navigator.of(context).pop();

      if (invoice != null) {
        final invoiceUrl = invoice['invoice_url'];

        if (invoiceUrl != null && invoiceUrl.toString().isNotEmpty) {
          print('🚀 Attempting to launch payment URL...');
          // Launch payment URL
          final launched = await XenditService.instance.launchPayment(invoiceUrl.toString());

          if (launched) {
            _showSuccessMessage('Payment page opened. Complete your payment in the browser.');
            // Optionally, you can implement payment status checking here
          } else {
            print('❌ Failed to launch payment URL');
            // Show the URL to user as fallback
            _showPaymentUrlDialog(invoiceUrl.toString());
          }
        } else {
          print('❌ No invoice URL in response: $invoice');
          _showErrorMessage('Invalid payment URL received from payment service.');
        }
      } else {
        _showErrorMessage('Failed to create payment invoice. Please try again.');
      }
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print('❌ Payment processing error: $e');
      _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Constants.primaryColor),
                SizedBox(height: 16),
                Text('Processing payment...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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

  void _showDemoPaymentDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demo Payment'),
        content: Text(
          'Demo payment of ₱${amount.toStringAsFixed(2)} via ${_getPaymentMethodName(_selectedPaymentMethod!)}.\n\n'
          'In a real app, this would redirect to the actual payment gateway.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSuccessMessage('Demo payment completed successfully!');
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

  void _showPaymentUrlDialog(String paymentUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Payment URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to open payment page automatically. You can:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              SelectableText(
                paymentUrl,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Constants.primaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openPaymentInWebView(paymentUrl);
              },
              child: const Text('Open in WebView'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Try to launch again
                Navigator.of(context).pop();
                final launched = await XenditService.instance.launchPayment(paymentUrl);
                if (launched) {
                  _showSuccessMessage('Payment page opened successfully!');
                } else {
                  _showErrorMessage('Still unable to open payment page. Please copy the URL manually.');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  void _openPaymentInWebView(String paymentUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentWebViewScreen(paymentUrl: paymentUrl),
      ),
    );
  }

  String _getPaymentMethodName(String value) {
    switch (value) {
      case 'gcash':
        return 'GCash E-Wallet';
      case 'grabpay':
        return 'GrabPay E-Wallet';
      case 'paymaya':
        return 'Maya E-Wallet';
      case 'bank_transfer':
        return 'Bank Transfer (Generic)';
      case 'bpi':
        return 'BPI Direct Debit';
      case 'bdo':
        return 'BDO Online Banking';
      case 'metrobank':
        return 'Metrobank Online';
      case 'unionbank':
        return 'UBP Direct Debit';
      case 'rcbc':
        return 'RCBC Direct Debit';
      case 'chinabank':
        return 'China Bank Direct Debit';
      case 'card':
        return 'Credit/Debit Card';
      default:
        return value;
    }
  }
}

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation for payment flow
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Constants.primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
