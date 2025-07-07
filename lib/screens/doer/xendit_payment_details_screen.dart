import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:qr_flutter/qr_flutter.dart'; // For QR code generation
import 'package:url_launcher/url_launcher.dart'; // For opening deep links
import 'package:intl/intl.dart'; // For date formatting

class XenditPaymentDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> paymentDetails;

  const XenditPaymentDetailsScreen({super.key, required this.paymentDetails});

  @override
  Widget build(BuildContext context) {
    final String paymentMethod = paymentDetails['payment_method'] ?? 'N/A';
    final String amount = (paymentDetails['amount'] as double?)?.toStringAsFixed(2) ?? '0.00';
    final String status = paymentDetails['status'] ?? 'PENDING';
    final String? vaNumber = paymentDetails['va_number'];
    final String? qrCodeString = paymentDetails['qr_code_string'];
    final String? checkoutUrl = paymentDetails['checkout_url'];
    final DateTime? expiresAt = paymentDetails['expires_at'] != null
        ? DateTime.tryParse(paymentDetails['expires_at'])
        : null;

    String instructionTitle = 'Payment Instructions';
    Widget paymentSpecificContent;
    IconData paymentIcon;

    if (paymentMethod.contains('BANK_TRANSFER')) {
      instructionTitle = 'Bank Transfer Instructions (${paymentDetails['payment_channel_code']})';
      paymentIcon = Icons.account_balance;
      paymentSpecificContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Virtual Account Number:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SelectableText(
            vaNumber ?? 'N/A',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Constants.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text(
            'Transfer the exact amount to the virtual account number above. Ensure the bank account name matches "Xendit".',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      );
    } else if (paymentMethod.contains('EWALLET')) {
      instructionTitle = 'E-Wallet Payment Instructions (${paymentDetails['payment_channel_code']})';
      paymentIcon = Icons.account_balance_wallet;
      if (qrCodeString != null && qrCodeString.isNotEmpty) {
        paymentSpecificContent = Column(
          children: [
            Text(
              'Scan this QR code using your ${paymentDetails['payment_channel_code']} app:',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: qrCodeString,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
              foregroundColor: Constants.textColor,
              errorStateBuilder: (cxt, err) {
                return const Center(child: Text('Uh oh! Something went wrong with QR code generation.'));
              },
            ),
            const SizedBox(height: 16),
            if (checkoutUrl != null && checkoutUrl.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
                    await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open the payment link.')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: Text('Open ${paymentDetails['payment_channel_code']} App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        );
      } else if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        paymentSpecificContent = Column(
          children: [
            Text(
              'Click the button below to complete payment using your ${paymentDetails['payment_channel_code']} app:',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
                  await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the payment link.')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text('Open ${paymentDetails['payment_channel_code']} App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      } else {
        paymentSpecificContent = const Text('No specific instructions available. Please refer to your e-wallet app.', style: TextStyle(fontSize: 16, color: Colors.grey));
      }
    } else {
      instructionTitle = 'Generic Payment Instructions';
      paymentIcon = Icons.info_outline;
      paymentSpecificContent = const Text('Please follow the instructions provided by Xendit for your selected payment method.', style: TextStyle(fontSize: 16, color: Colors.grey));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash In Details'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(paymentIcon, size: 30, color: Constants.primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            instructionTitle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.textColor),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    _buildDetailRow('Amount to Pay:', 'P$amount', isAmount: true),
                    _buildDetailRow('Status:', status.toUpperCase(),
                        color: status == 'PAID' ? Colors.green : (status == 'PENDING' ? Colors.orange : Colors.red)),
                    _buildDetailRow('Payment Method:', paymentMethod),
                    if (expiresAt != null)
                      _buildDetailRow(
                        'Expires By:',
                        DateFormat('MMM d, yyyy h:mm a').format(expiresAt),
                        color: expiresAt.isBefore(DateTime.now()) ? Colors.red : null,
                      ),
                    const SizedBox(height: 20),
                    paymentSpecificContent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Important Notes:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 8),
            const Text(
              '- Please complete the payment within the expiration time.\n'
                  '- Funds will be automatically credited to your HanApp balance once payment is confirmed by Xendit.\n'
                  '- You can check your transaction history for updates.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isAmount ? 20 : 16,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isAmount ? Constants.primaryColor : Constants.textColor),
            ),
          ),
        ],
      ),
    );
  }
}
