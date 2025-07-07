import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChannels.lifecycle
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/transaction.dart';
import 'package:hanapp/services/wallet_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Add url_launcher: ^6.2.1 in pubspec.yaml

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  User? _currentUser;
  double _balance = 0.00;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedPaymentMethod;
  final TextEditingController _amountController = TextEditingController();
  final WalletService _walletService = WalletService();

  // Payment methods for Xendit. The 'value' corresponds to Xendit's API channel codes or a generic type.
  final List<Map<String, String>> _paymentMethods = [
    {'name': 'GCash', 'value': 'gcash'},
    {'name': 'Paymaya', 'value': 'paymaya'},
    {'name': 'Bank Transfer (via Xendit Invoice)', 'value': 'bank_transfer'}, // User selects specific bank on Xendit page
    {'name': 'Credit/Debit Card (via Xendit Invoice)', 'value': 'card'}, // User enters card details on Xendit page
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer for app lifecycle
    _initializeWalletScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _amountController.dispose();
    super.dispose();
  }

  // --- App Lifecycle Management ---
  // This method is called when the app's lifecycle state changes.
  // We use it to refresh data when the app returns from background (e.g., after Xendit payment).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App has come back to the foreground
      debugPrint('App resumed: Refreshing wallet data...');
      _initializeWalletScreen(); // Re-fetch all data
    }
  }

  Future<void> _initializeWalletScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _currentUser = await AuthService.getUser();
    if (_currentUser == null || _currentUser!.id == null) {
      _errorMessage = 'User not logged in. Please log in to view wallet.';
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await Future.wait([
      _fetchBalance(),
      _fetchTransactionHistory(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchBalance() async {
    if (_currentUser == null || _currentUser!.id == null) return;
    final response = await _walletService.getWalletBalance(userId: _currentUser!.id!);
    if (response['success']) {
      setState(() {
        _balance = response['balance'];
      });
    } else {
      _errorMessage = response['message'] ?? 'Failed to load balance.';
      _showSnackBar(_errorMessage!, isError: true);
    }
  }

  Future<void> _fetchTransactionHistory() async {
    if (_currentUser == null || _currentUser!.id == null) return;
    final response = await _walletService.getTransactionHistory(userId: _currentUser!.id!);
    if (response['success']) {
      setState(() {
        _transactions = response['transactions'];
      });
    } else {
      _errorMessage = response['message'] ?? 'Failed to load transaction history.';
      _showSnackBar(_errorMessage!, isError: true);
    }
  }

  Future<void> _handleCashIn() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in. Please log in to cash in.', isError: true);
      return;
    }
    if (_selectedPaymentMethod == null) {
      _showSnackBar('Please select a payment method.', isError: true);
      return;
    }
    final String amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter an amount.', isError: true);
      return;
    }
    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid positive amount.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Pass user's email and full name to the backend for Xendit invoice creation
    final response = await _walletService.initiateCashIn(
      userId: _currentUser!.id!,
      amount: amount,
      paymentMethod: _selectedPaymentMethod!,
      userEmail: _currentUser!.email,
      userFullName: _currentUser!.fullName,
    );

    setState(() {
      _isLoading = false; // Hide loading indicator
    });

    if (response['success']) {
      _showSnackBar(response['message']);
      _amountController.clear(); // Clear amount input

      final String? redirectUrl = response['redirect_url'];
      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        debugPrint('Opening Xendit URL: $redirectUrl');
        // Open the Xendit hosted payment page
        if (await canLaunchUrl(Uri.parse(redirectUrl))) {
          await launchUrl(Uri.parse(redirectUrl), mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not open Xendit payment page. URL: $redirectUrl', isError: true);
        }
        // No direct balance/history refresh here. It happens via webhook after payment completion,
        // and triggered by app resume (didChangeAppLifecycleState).
      } else {
        // This case might happen if a payment method doesn't require a redirect
        // and backend mistakenly returned no URL. For now, just refresh.
        debugPrint('No redirect URL provided by Xendit, refreshing data.');
        await _fetchBalance();
        await _fetchTransactionHistory();
      }
    } else {
      _showSnackBar('Cash In Failed: ${response['message']}', isError: true);
      debugPrint('Cash In Failed Details: ${response['message']}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
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
                onPressed: _initializeWalletScreen,
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
            // Wallet Balance Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Balance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Constants.textColor.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₱${_balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Constants.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Cash In Method Section
            Text(
              'Cash in Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._paymentMethods.map((method) {
                      return RadioListTile<String>(
                        title: Text(method['name']!),
                        value: method['value']!,
                        groupValue: _selectedPaymentMethod,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedPaymentMethod = value;
                          });
                        },
                        activeColor: Constants.primaryColor,
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], // Allows up to 2 decimal places
                      decoration: InputDecoration(
                        labelText: 'Amount (PHP)',
                        prefixText: '₱',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Constants.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCashIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Cash In',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transaction History Section
            Text(
              'Transaction History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _transactions.isEmpty
                ? Center(
              child: Text(
                'No transactions yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final transaction = _transactions[index];
                Color statusColor;
                String statusText = transaction.status;

                switch (transaction.status.toLowerCase()) {
                  case 'completed':
                  case 'settled':
                    statusColor = Colors.green.shade700;
                    statusText = 'Completed';
                    break;
                  case 'pending':
                    statusColor = Colors.orange.shade700;
                    break;
                  case 'in_process':
                    statusColor = Colors.blue.shade700;
                    statusText = 'In Process';
                    break;
                  case 'failed':
                    statusColor = Colors.red.shade700;
                    break;
                  case 'cancelled':
                    statusColor = Colors.grey.shade700;
                    break;
                  case 'expired':
                    statusColor = Colors.purple.shade700;
                    break;
                  default:
                    statusColor = Colors.black54;
                    break;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          transaction.type == 'cash_in'
                              ? Icons.add_circle_outline
                              : transaction.type == 'withdrawal'
                              ? Icons.remove_circle_outline
                              : Icons.info_outline,
                          color: transaction.type == 'cash_in' ? Colors.green : Colors.red,
                          size: 30,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.description ?? '${transaction.type.replaceAll('_', ' ')} via ${transaction.method ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy - hh:mm a').format(transaction.transactionDate),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (transaction.xenditInvoiceId != null && transaction.xenditInvoiceId!.isNotEmpty)
                                Text(
                                  'Xendit Ref: ${transaction.xenditInvoiceId}',
                                  style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade400),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${transaction.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: transaction.type == 'cash_in' ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusText,
                              style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
