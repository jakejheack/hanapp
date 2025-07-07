import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/auth_service.dart'; // To get current user
import 'package:hanapp/models/user.dart'; // User model
import 'package:hanapp/models/withdrawal_request.dart'; // NEW: Import withdrawal request model
import 'package:hanapp/services/withdrawal_service.dart'; // Withdrawal Service
import 'package:intl/intl.dart'; // For currency formatting

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountDetailsController = TextEditingController();
  String? _selectedMethod;
  User? _currentUser;
  double _totalProfit = 0.0;
  bool _isVerified = false;
  bool _isLoading = false;
  final WithdrawalService _withdrawalService = WithdrawalService();

  // NEW: Withdrawal history state variables
  List<WithdrawalRequest> _withdrawalHistory = [];
  bool _isLoadingHistory = false;
  String? _historyErrorMessage;

  final List<String> _withdrawalMethods = ['Bank Transfer', 'PayPal', 'GCash'];
  final double _minimumWithdrawalAmount = 200.00; // Minimum withdrawal amount

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFinancialDetails();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountDetailsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndFinancialDetails() async {
    setState(() {
      _isLoading = true;
    });
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Fetch financial details from backend
    final financialResponse = await _withdrawalService.getUserFinancialDetails(_currentUser!.id);
    if (financialResponse['success']) {
      setState(() {
        _totalProfit = financialResponse['total_profit'];
        _isVerified = financialResponse['is_verified'];
      });
    } else {
      _showSnackBar(financialResponse['message'] ?? 'Failed to load financial details.', isError: true);
    }

    // NEW: Fetch withdrawal history
    await _loadWithdrawalHistory();

    setState(() {
      _isLoading = false;
    });
  }

  // NEW: Load withdrawal history from backend
  Future<void> _loadWithdrawalHistory() async {
    if (_currentUser == null || _currentUser!.id == null) return;

    setState(() {
      _isLoadingHistory = true;
      _historyErrorMessage = null;
    });

    final response = await _withdrawalService.getWithdrawalHistory(_currentUser!.id);
    
    setState(() {
      _isLoadingHistory = false;
    });

    if (response['success']) {
      setState(() {
        _withdrawalHistory = response['withdrawals'];
      });
    } else {
      setState(() {
        _historyErrorMessage = response['message'] ?? 'Failed to load withdrawal history.';
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
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

  Future<void> _submitWithdrawal() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    final String amountText = _amountController.text.trim();
    final String accountDetails = _accountDetailsController.text.trim();

    if (amountText.isEmpty || _selectedMethod == null || accountDetails.isEmpty) {
      _showSnackBar('Please fill all withdrawal details.', isError: true);
      return;
    }

    final double amount = double.tryParse(amountText) ?? 0.0;

    if (amount < _minimumWithdrawalAmount) {
      _showSnackBar('Minimum amount of P${_minimumWithdrawalAmount.toStringAsFixed(2)} required for withdrawal.', isError: true);
      return;
    }

    if (amount > _totalProfit) {
      _showSnackBar('Insufficient balance. Your total profit is P${_totalProfit.toStringAsFixed(2)}.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await _withdrawalService.submitWithdrawal(
      userId: _currentUser!.id,
      amount: amount,
      method: _selectedMethod!,
      accountDetails: accountDetails,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar('Withdrawal request submitted successfully! It will be processed soon.');
      // Clear fields and refresh profit
      _amountController.clear();
      _accountDetailsController.clear();
      setState(() {
        _selectedMethod = null; // Reset selected method
      });
      _loadUserDataAndFinancialDetails(); // Refresh total profit and withdrawal history
    } else {
      _showSnackBar('Withdrawal failed: ${response['message']}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _totalProfit == 0.0 && !_isVerified) { // Initial loading state
      return Scaffold(
        appBar: AppBar(
          title: const Text('Withdrawal'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Profit Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Constants.primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Profit:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'P${NumberFormat('#,##0.00').format(_totalProfit)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Verification Status Card
            if (!_isVerified)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Verification Required',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'You need to complete identity verification before you can withdraw funds. Please go to your profile settings to verify your identity.',
                        style: TextStyle(fontSize: 14, color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/verification');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Go to Verification Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isVerified) const SizedBox(height: 32),

            // Withdrawal Form (only show if verified)
            if (_isVerified) ...[
              // Withdrawal Method Section
              const Text(
                'Withdrawal Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 16),
              Column(
                children: _withdrawalMethods.map((method) {
                  return RadioListTile<String>(
                    title: Text(method),
                    value: method,
                    groupValue: _selectedMethod,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedMethod = value;
                      });
                    },
                    activeColor: Constants.primaryColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountDetailsController,
                decoration: InputDecoration(
                  labelText: _selectedMethod == 'Bank Transfer'
                      ? 'Bank Account Number & Name'
                      : _selectedMethod == 'PayPal'
                      ? 'PayPal Email'
                      : _selectedMethod == 'GCash'
                      ? 'GCash Number'
                      : 'Account Details',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g., 1234567890 (John Doe) / your@email.com / 09xxxxxxxxx',
                ),
                keyboardType: TextInputType.text, // Can be text for names/emails
                maxLines: null, // Allow multiple lines for bank details
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount to Withdraw (Min P${_minimumWithdrawalAmount.toStringAsFixed(2)})',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: 'P',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Withdraw',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Transaction History Section
            const Text(
              'Transaction History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 16),
            
            // Dynamic withdrawal history
            if (_isLoadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (_historyErrorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _historyErrorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_withdrawalHistory.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No withdrawal history yet.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...(_withdrawalHistory.map((withdrawal) => _buildWithdrawalHistoryItem(withdrawal)).toList()),
          ],
        ),
      ),
    );
  }

  // Helper to build transaction history items
  Widget _buildTransactionHistoryItem({
    required String type,
    required String date,
    required String status,
    required Color statusColor,
    double? amount, // NEW: Optional amount parameter
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date: $date',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Amount: P${NumberFormat('#,##0.00').format(amount)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Constants.primaryColor),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(WithdrawalRequest withdrawal) {
    return _buildTransactionHistoryItem(
      type: 'Withdrawal - ${withdrawal.method}',
      date: DateFormat('MMM d, yyyy').format(withdrawal.requestDate),
      status: withdrawal.getStatusDisplayText(),
      statusColor: withdrawal.getStatusColor(),
      amount: withdrawal.amount,
    );
  }
}
