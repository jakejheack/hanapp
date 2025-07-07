import 'package:flutter/material.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/utils/listing_service.dart'; // Assuming a service for job confirmation

class ConfirmJobScreen extends StatefulWidget {
  const ConfirmJobScreen({super.key});

  @override
  State<ConfirmJobScreen> createState() => _ConfirmJobScreenState();
}

class _ConfirmJobScreenState extends State<ConfirmJobScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _jobData;
  final ListingService _listingService = ListingService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (_jobData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job data not provided.')),
      );
      Navigator.of(context).pop(false); // Go back if data is missing
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _confirmJob() async {
    if (_jobData == null || _jobData!['listingId'] == null || _jobData!['listerId'] == null) {
      _showSnackBar('Missing job or user ID.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // In a real app, you might update the application status to 'hired'
    // and then mark the listing as 'completed'
    // For simplicity, this example will just mark the listing as complete directly.
    final response = await _listingService.completeListing(
      _jobData!['listingId'],
      _jobData!['listerId'],
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar('Job confirmed and listing marked as complete!');
      Navigator.of(context).pop(true); // Indicate success
    } else {
      _showSnackBar('Failed to confirm job: ${response['message']}', isError: true);
      Navigator.of(context).pop(false); // Indicate failure
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid job data.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Job'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 100, color: Colors.green.shade400),
            const SizedBox(height: 24),
            Text(
              'Confirm job for "${_jobData!['listingTitle']}" with ${_jobData!['applicantName']}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'By confirming, you are indicating that the job has been successfully completed by the applicant.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
              text: 'Confirm Job',
              onPressed: _confirmJob,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Cancel',
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}