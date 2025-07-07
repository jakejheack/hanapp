import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/transaction.dart';
import 'package:hanapp/services/wallet_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart';
// Note: url_launcher is not needed on this screen as there's no payment initiation.

class WalletDetailsScreen extends StatefulWidget {
  const WalletDetailsScreen({super.key});

  @override
  State<WalletDetailsScreen> createState() => _WalletDetailsScreenState();
}

class _WalletDetailsScreenState extends State<WalletDetailsScreen> with WidgetsBindingObserver {
  User? _currentUser;
  double _balance = 0.00;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  final WalletService _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
    _initializeWalletDetailsScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  // --- App Lifecycle Management ---
  // This is useful if a user completes a payment in BecauseScreen,
  // then navigates to this WalletDetailsScreen, it will refresh the data.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed: Refreshing wallet details...');
      _initializeWalletDetailsScreen(); // Re-fetch all data
    }
  }

  Future<void> _initializeWalletDetailsScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _currentUser = await AuthService.getUser();
    if (_currentUser == null || _currentUser!.id == null) {
      _errorMessage = 'User not logged in. Please log in to view wallet details.';
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Fetch both balance and transaction history concurrently
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
        title: const Text('HanApp Balance'), // Title specific to this screen
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
                onPressed: _initializeWalletDetailsScreen,
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
                      'Current Balance',
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
