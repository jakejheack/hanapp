import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({Key? key}) : super(key: key);

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  double balance = 5240.00;
  String selectedMethod = 'Bank Transfer';

  // Mock transaction data
  List<Transaction> transactions = [
    Transaction(
        title: "Withdrawal - Bank",
        date: DateTime(2023, 11, 1),
        status: TransactionStatus.completed),
    Transaction(
        title: "Additional Orders",
        date: DateTime(2023, 10, 25),
        status: TransactionStatus.inProcess),
    Transaction(
        title: "Affiliate Bonus",
        date: DateTime(2023, 10, 20),
        status: TransactionStatus.cancelled),
  ];

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 20),
            Text(
              'Cash in Method',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            _buildPaymentMethods(),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleCashIn,
                child: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Cash in'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Transaction History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(child: _buildTransactionHistory()),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text(
              'Balance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '₱${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('Bank Transfer'),
          value: 'Bank Transfer',
          groupValue: selectedMethod,
          onChanged: (value) {
            setState(() {
              selectedMethod = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('Paymaya'),
          value: 'Paymaya',
          groupValue: selectedMethod,
          onChanged: (value) {
            setState(() {
              selectedMethod = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text('GCash'),
          value: 'GCash',
          groupValue: selectedMethod,
          onChanged: (value) {
            setState(() {
              selectedMethod = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTransactionHistory() {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transaction history.'));
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: Text(tx.title),
            subtitle: Text('Date: ${_formatDate(tx.date)}'),
            trailing: Text(
              _statusText(tx.status),
              style: TextStyle(color: _statusColor(tx.status)),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _statusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.inProcess:
        return 'In Process';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.inProcess:
        return Colors.orange;
      case TransactionStatus.cancelled:
        return Colors.red;
    }
  }

  Future<void> _handleCashIn() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user
      final user = await AuthService.getUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      setState(() {
        isLoading = false;
      });

      // Navigate to the new PaymentScreen
      Navigator.pushNamed(
        context,
        '/payment',
        arguments: {
          'amount': 1000.0, // Default amount, user can change it
          'user': user,
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to open payment screen: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                )
              ],
            );
          });
    }
  }


}

enum TransactionStatus { completed, inProcess, cancelled }

class Transaction {
  final String title;
  final DateTime date;
  final TransactionStatus status;

  Transaction({
    required this.title,
    required this.date,
    required this.status,
  });
}