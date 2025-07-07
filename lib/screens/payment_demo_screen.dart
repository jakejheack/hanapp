import 'package:flutter/material.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;

class PaymentDemoScreen extends StatefulWidget {
  const PaymentDemoScreen({super.key});

  @override
  State<PaymentDemoScreen> createState() => _PaymentDemoScreenState();
}

class _PaymentDemoScreenState extends State<PaymentDemoScreen> {
  final TextEditingController _amountController = TextEditingController(text: '100.00');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Demo'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Integration Demo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This demo shows the payment integration copied from your authtest project. You can test different payment methods including GCash, GrabPay, Maya, Credit/Debit Card, and Bank Transfer.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            // Amount Input
            const Text(
              'Amount to Pay:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₱ ',
                hintText: 'Enter amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            
            const SizedBox(height: 32),
            
            // Payment Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _openPaymentScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Open Payment Screen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Features List
            const Text(
              'Features Included:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureItem(
                  icon: Icons.account_balance_wallet,
                  title: 'E-Wallet Payments',
                  description: 'GCash, GrabPay, Maya support',
                ),
                _FeatureItem(
                  icon: Icons.credit_card,
                  title: 'Card Payments',
                  description: 'Credit and Debit cards',
                ),
                _FeatureItem(
                  icon: Icons.account_balance,
                  title: 'Bank Transfer',
                  description: 'BPI, China Bank, RCBC, UBP',
                ),
                _FeatureItem(
                  icon: Icons.web,
                  title: 'WebView Integration',
                  description: 'In-app payment processing',
                ),
                _FeatureItem(
                  icon: Icons.security,
                  title: 'Xendit Integration',
                  description: 'Secure payment processing',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPaymentScreen() async {
    try {
      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        _showError('Please enter an amount');
        return;
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        _showError('Please enter a valid amount');
        return;
      }

      // Get current user
      final user = await AuthService.getUser();
      if (user == null) {
        _showError('User not logged in. Please log in first.');
        return;
      }

      // Navigate to payment screen
      Navigator.pushNamed(
        context,
        '/payment',
        arguments: {
          'amount': amount,
          'user': user,
        },
      );
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Constants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Constants.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
