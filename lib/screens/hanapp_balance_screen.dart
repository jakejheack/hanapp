import 'package:flutter/material.dart';
import 'package:hanapp/models/balance.dart';
import 'package:hanapp/models/transaction.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/balance_service.dart';
import 'package:intl/intl.dart';

class HanAppBalanceScreen extends StatefulWidget {
  const HanAppBalanceScreen({super.key});

  @override
  State<HanAppBalanceScreen> createState() => _HanAppBalanceScreenState();
}

class _HanAppBalanceScreenState extends State<HanAppBalanceScreen> {
  final BalanceService _balanceService = BalanceService();
  double _currentBalance = 0.0;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  int? _currentUserId;
  String? _selectedCashInMethod;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchBalance();
  }

  Future<void> _loadUserDataAndFetchBalance() async {
    final user = await AuthService.getUser();
    if (user == null || user.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      Navigator.of(context).pop();
      return;
    }
    _currentUserId = user.id;
    _fetchBalanceAndTransactions();
  }

  Future<void> _fetchBalanceAndTransactions() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    // Fetch Balance
    final balanceResponse = await _balanceService.getBalance(_currentUserId!);
    if (balanceResponse['success']) {
      _currentBalance = (balanceResponse['balance'] as Balance).amount;
    } else {
      _showSnackBar('Failed to load balance: ${balanceResponse['message']}', isError: true);
      _currentBalance = 0.0;
    }

    // Fetch Transactions
    final transactionsResponse = await _balanceService.getTransactions(_currentUserId!);
    if (transactionsResponse['success']) {
      _transactions = transactionsResponse['transactions'];
      // _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
    } else {
      _showSnackBar('Failed to load transactions: ${transactionsResponse['message']}', isError: true);
      _transactions = [];
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _cashIn() {
    if (_selectedCashInMethod == null) {
      _showSnackBar('Please select a cash-in method.', isError: true);
      return;
    }
    // Implement cash-in logic here. This is a placeholder.
    _showSnackBar('Cash in via $_selectedCashInMethod not yet implemented.');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in process':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        title: const Text('Balance'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchBalanceAndTransactions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₱${_currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34495E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Cash in Method Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash in Method',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      RadioListTile<String>(
                        title: const Text('Bank Transfer'),
                        value: 'Bank Transfer',
                        groupValue: _selectedCashInMethod,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedCashInMethod = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Paymaya'),
                        value: 'Paymaya',
                        groupValue: _selectedCashInMethod,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedCashInMethod = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('GCash'),
                        value: 'GCash',
                        groupValue: _selectedCashInMethod,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedCashInMethod = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cashIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF34495E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cash in',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select your preferred withdrawal method to proceed.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Transaction History Section
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _transactions.isEmpty
                  ? const Center(child: Text('No transactions found.'))
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            // children: [
                            //   Text(
                            //     transaction.description,
                            //     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            //   ),
                            //   Text(
                            //     '${DateFormat('MMM d, yyyy').format(transaction.createdAt)}',
                            //     style: const TextStyle(fontSize: 14, color: Colors.grey),
                            //   ),
                            // ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${transaction.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: transaction.type == 'withdrawal' ? Colors.red : Colors.green,
                                ),
                              ),
                              Text(
                                transaction.status,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getStatusColor(transaction.status),
                                  fontWeight: FontWeight.w500,
                                ),
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
      ),
    );
  }
}