import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/transaction.dart';
import 'package:hanapp/services/wallet_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String xenditInvoiceId;
  final int userId;
  final double amount;
  final String paymentMethod;

  const PaymentStatusScreen({
    super.key,
    required this.xenditInvoiceId,
    required this.userId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> with WidgetsBindingObserver {
  Transaction? _paymentTransaction;
  bool _isLoading = true;
  String? _errorMessage;
  final WalletService _walletService = WalletService();
  bool _pollingActive = true; // Control polling

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
    _fetchPaymentStatusPeriodically(); // Start polling
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingActive = false; // Stop polling when screen is disposed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed: Re-fetching payment status...');
      _fetchPaymentStatus(); // Fetch status immediately when app resumes
    }
  }

  Future<void> _fetchPaymentStatusPeriodically() async {
    while (_pollingActive && _paymentTransaction?.status != 'completed' && _paymentTransaction?.status != 'failed' && _paymentTransaction?.status != 'expired' && mounted) {
      await _fetchPaymentStatus();
      if (_pollingActive && _paymentTransaction?.status != 'completed' && _paymentTransaction?.status != 'failed' && _paymentTransaction?.status != 'expired') {
        await Future.delayed(const Duration(seconds: 5)); // Poll every 5 seconds
      }
    }
  }

  Future<void> _fetchPaymentStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _walletService.getTransactionHistory(userId: widget.userId);
    if (response['success']) {
      final List<Transaction> transactions = response['transactions'];
      _paymentTransaction = transactions.firstWhere(
            (txn) => txn.xenditInvoiceId == widget.xenditInvoiceId,
        orElse: () => throw Exception('Transaction not found in history with Xendit ID: ${widget.xenditInvoiceId}'),
      );
    } else {
      _errorMessage = response['message'] ?? 'Failed to load transaction status.';
      _showSnackBar(_errorMessage!, isError: true);
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
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
    IconData statusIcon;
    Color statusColor;
    String statusMessage;

    if (_isLoading) {
      statusIcon = Icons.hourglass_empty;
      statusColor = Colors.orange;
      statusMessage = 'Checking payment status...';
    } else if (_errorMessage != null) {
      statusIcon = Icons.error_outline;
      statusColor = Colors.red;
      statusMessage = _errorMessage!;
    } else if (_paymentTransaction == null) {
      statusIcon = Icons.help_outline;
      statusColor = Colors.grey;
      statusMessage = 'Transaction details not found.';
    } else {
      switch (_paymentTransaction!.status.toLowerCase()) {
        case 'completed':
        case 'settled':
          statusIcon = Icons.check_circle_outline;
          statusColor = Colors.green.shade700;
          statusMessage = 'Payment Completed Successfully!';
          break;
        case 'pending':
          statusIcon = Icons.hourglass_top;
          statusColor = Colors.orange.shade700;
          statusMessage = 'Payment is still pending. Please wait for confirmation.';
          break;
        case 'failed':
          statusIcon = Icons.cancel_outlined;
          statusColor = Colors.red.shade700;
          statusMessage = 'Payment Failed. Please try again.';
          break;
        case 'cancelled':
          statusIcon = Icons.cancel;
          statusColor = Colors.grey.shade700;
          statusMessage = 'Payment Cancelled.';
          break;
        case 'expired':
          statusIcon = Icons.hourglass_disabled;
          statusColor = Colors.purple.shade700;
          statusMessage = 'Payment Expired. Please try again.';
          break;
        default:
          statusIcon = Icons.info_outline;
          statusColor = Colors.blueGrey;
          statusMessage = 'Unknown payment status: ${_paymentTransaction!.status}';
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, size: 80, color: statusColor),
              const SizedBox(height: 24),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 16),
              if (_paymentTransaction != null) ...[
                Text(
                  'Amount: ₱${_paymentTransaction!.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, color: Constants.textColor),
                ),
                Text(
                  'Method: ${_paymentTransaction!.method ?? 'N/A'}',
                  style: const TextStyle(fontSize: 16, color: Constants.textColor),
                ),
                Text(
                  'Transaction Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(_paymentTransaction!.transactionDate)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                if (_paymentTransaction!.xenditInvoiceId != null && _paymentTransaction!.xenditInvoiceId!.isNotEmpty)
                  Text(
                    'Xendit Ref: ${_paymentTransaction!.xenditInvoiceId}',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                  ),
                const SizedBox(height: 32),
              ],
              if (_isLoading)
                const CircularProgressIndicator(color: Constants.primaryColor),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : () => Navigator.popUntil(context, (route) => route.isFirst), // Go back to main screen or dashboard
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Go to Home', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 10),
              if (_paymentTransaction?.status != 'completed' && _paymentTransaction?.status != 'settled' && !_isLoading)
                TextButton(
                  onPressed: _fetchPaymentStatus, // Allow manual refresh
                  child: Text('Refresh Status', style: TextStyle(color: Constants.primaryColor)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
