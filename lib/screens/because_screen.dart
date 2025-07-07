import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/xendit_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BecauseScreen extends StatefulWidget {
  final double? preFilledAmount;
  final bool isJobPayment;
  final String? applicationId;
  final String? listingTitle;

  const BecauseScreen({
    super.key,
    this.preFilledAmount,
    this.isJobPayment = false,
    this.applicationId,
    this.listingTitle,
  });

  @override
  State<BecauseScreen> createState() => _BecauseScreenState();
}

class _BecauseScreenState extends State<BecauseScreen> {
  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedPaymentMethod;
  String? _selectedBank; // For bank transfer dropdown
  final TextEditingController _amountController = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _currentUser = await AuthService.getUser();
    if (_currentUser == null || _currentUser!.id == null) {
      _errorMessage = 'User not logged in. Please log in to make a payment.';
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Pre-fill amount if provided (for job payments)
    if (widget.preFilledAmount != null && widget.preFilledAmount! > 0) {
      _amountController.text = widget.preFilledAmount!.toStringAsFixed(2);
    }

    setState(() {
      _isLoading = false;
    });
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
      if (widget.isJobPayment) {
        // For job payments, show demo payment and return success
        _showDemoPaymentDialog(amount);
        return;
      } else {
        _showConfigurationDialog(amount);
        return;
      }
    }

    // Show loading
    _showLoadingDialog();

    try {
      // Determine the actual payment method to use
      String actualPaymentMethod = _selectedPaymentMethod!;
      if (_selectedPaymentMethod == 'bank_transfer' && _selectedBank != null) {
        actualPaymentMethod = _selectedBank!;
      }

      // Create description based on payment type
      String description;
      if (widget.isJobPayment && widget.listingTitle != null) {
        description = 'Payment for job: ${widget.listingTitle}';
      } else {
        description = 'Payment via ${_getPaymentMethodName(actualPaymentMethod)}';
      }

      // Create Xendit invoice
      final invoice = await XenditService.instance.createInvoice(
        amount: amount,
        paymentMethod: actualPaymentMethod,
        customerEmail: _currentUser!.email,
        customerName: _currentUser!.fullName,
        description: description,
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
            // For job payments, return success after a delay
            if (widget.isJobPayment) {
              Future.delayed(const Duration(seconds: 2), () {
                Navigator.of(context).pop(true); // Return success
              });
            }
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
        title: Text(widget.isJobPayment ? 'Demo Job Payment' : 'Demo Payment'),
        content: Text(
          widget.isJobPayment 
            ? 'Demo payment of ₱${amount.toStringAsFixed(2)} for job: ${widget.listingTitle ?? "Unknown Job"}.\n\n'
              'In a real app, this would redirect to the actual payment gateway.'
            : 'Demo payment of ₱${amount.toStringAsFixed(2)} via ${_getPaymentMethodName(_selectedPaymentMethod!)}.\n\n'
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
              _showSuccessMessage(widget.isJobPayment 
                ? 'Demo job payment completed successfully!' 
                : 'Demo payment completed successfully!');
              
              // For job payments, return success to chat screen
              if (widget.isJobPayment) {
                Future.delayed(const Duration(seconds: 1), () {
                  Navigator.of(context).pop(true); // Return success
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.isJobPayment ? 'Complete Demo Job Payment' : 'Complete Demo Payment'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.isJobPayment ? 'Job Payment' : 'Make a Payment',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 50),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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

            // Amount Input
            Container(
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: '₱ ',
                      prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Constants.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
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
