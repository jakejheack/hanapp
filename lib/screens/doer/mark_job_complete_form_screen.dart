import 'package:flutter/material.dart';
import 'package:hanapp/services/doer_job_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;

class MarkJobCompleteFormScreen extends StatefulWidget {
  final int applicationId;
  final String listingTitle;
  final double? suggestedPrice; // Confirmed: nullable double?

  const MarkJobCompleteFormScreen({
    super.key,
    required this.applicationId,
    required this.listingTitle,
    this.suggestedPrice,
  });

  @override
  State<MarkJobCompleteFormScreen> createState() => _MarkJobCompleteFormScreenState();
}

class _MarkJobCompleteFormScreenState extends State<MarkJobCompleteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _earnedAmountController = TextEditingController();
  final TextEditingController _transactionNoController = TextEditingController();
  bool _isLoading = false;
  User? _currentUser;

  final DoerJobService _doerJobService = DoerJobService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    if (widget.suggestedPrice != null) {
      _earnedAmountController.text = widget.suggestedPrice!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _earnedAmountController.dispose();
    _transactionNoController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      if (mounted) {
        _showSnackBar('User not logged in. Please log in again.', isError: true);
        Navigator.of(context).pushReplacementNamed('/login');
      }
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double? earnedAmount = double.tryParse(_earnedAmountController.text.trim());
    final String transactionNo = _transactionNoController.text.trim();

    if (earnedAmount == null || earnedAmount <= 0) {
      _showSnackBar('Please enter a valid amount earned.', isError: true);
      return;
    }
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _doerJobService.markApplicationComplete(
        applicationId: widget.applicationId,
        doerId: _currentUser!.id!,
        earnedAmount: earnedAmount,
        transactionNo: transactionNo,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        _showSnackBar('Job successfully marked as complete.');
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showSnackBar(response['message'] ?? 'Failed to mark job complete.', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Network error: $e', isError: true);
      debugPrint('Error marking job complete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Job Complete'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completing: ${widget.listingTitle}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _earnedAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount Earned (PHP)',
                  hintText: 'e.g., ${widget.suggestedPrice?.toStringAsFixed(2) ?? '0.00'}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: 'P',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the amount earned.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number.';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be positive.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _transactionNoController,
                decoration: InputDecoration(
                  labelText: 'Transaction Number (Optional)',
                  hintText: 'e.g., GCash Ref #',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Submit Completion',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
