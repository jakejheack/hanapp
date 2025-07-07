import 'package:flutter/material.dart';
import 'package:hanapp/services/doer_job_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/notification_popup_service.dart';
import 'package:hanapp/models/notification_model.dart';

class CancelJobApplicationFormScreen extends StatefulWidget {
  final int applicationId;
  final String listingTitle;

  const CancelJobApplicationFormScreen({
    super.key,
    required this.applicationId,
    required this.listingTitle,
  });

  @override
  State<CancelJobApplicationFormScreen> createState() => _CancelJobApplicationFormScreenState();
}

class _CancelJobApplicationFormScreenState extends State<CancelJobApplicationFormScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final DoerJobService _doerJobService = DoerJobService();
  User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
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

  Future<void> _submitCancellation() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    final String cancellationReason = _reasonController.text.trim();

    setState(() {
      _isLoading = true;
    });

    final response = await _doerJobService.cancelApplication(
      applicationId: widget.applicationId,
      doerId: _currentUser!.id,
      cancellationReason: cancellationReason.isEmpty ? null : cancellationReason,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message']);
      
      // Create and show popup notification for the lister
      // Note: We don't have the lister's ID here, so the backend notification will handle this
      // But we can show a popup notification for the doer confirming their cancellation
      final notification = NotificationModel(
        id: 0, // This will be set by the backend
        userId: _currentUser!.id, // Doer's ID (showing to themselves)
        senderId: _currentUser!.id, // Doer's ID
        type: 'application_cancelled',
        title: 'Application Cancelled',
        content: "Your application for '${widget.listingTitle}' has been cancelled successfully.",
        createdAt: DateTime.now(),
        isRead: false,
        associatedId: widget.applicationId,
        relatedListingTitle: widget.listingTitle,
      );
      
      // Show popup notification for the doer
      NotificationPopupService().showNotification(context, notification);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Indicate success to previous screen
      }
    } else {
      _showSnackBar(response['message'] ?? 'Failed to cancel application.', isError: true);
      if (mounted) {
        Navigator.of(context).pop(false); // Indicate failure to previous screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancel Application'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job: ${widget.listingTitle}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for cancellation (Optional)',
                hintText: 'e.g., I am no longer available for this job.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCancellation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Confirm Cancellation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
