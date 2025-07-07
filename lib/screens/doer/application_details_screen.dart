import 'package:flutter/material.dart';
import 'package:hanapp/models/doer_job.dart'; // Import your DoerJob model
import 'package:hanapp/utils/constants.dart' as Constants; // For colors and text styles
import 'package:intl/intl.dart';

import 'cancel_job_application_form_screen.dart'; // For date formatting

class ApplicationDetailsScreen extends StatelessWidget {
  final DoerJob job; // The DoerJob object passed from the previous screen

  const ApplicationDetailsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white, // Back button color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Title
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            Text(
              'P${job.price?.toStringAsFixed(2) ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Constants.primaryColor,
              ),
            ),
            const SizedBox(height: 4),

            // Location Address
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.locationAddress ?? 'Location not specified',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Posted Time (using appliedAt as a proxy for now, but ideally listing_created_at)
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  job.listingCreatedAt != null
                      ? DateFormat('MMM d, yyyy').format(job.listingCreatedAt!)
                      : 'Date not available', // Format date
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                // You might need a utility function to calculate "hours ago"
                const Text(
                  ' | X hours ago', // Placeholder for "X hours ago"
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Listing Description
            Text(
              job.description ?? 'No description provided.',
              style: const TextStyle(fontSize: 16, color: Constants.textColor),
            ),
            const SizedBox(height: 24),

            // Your Application Description Section
            const Text(
              'Your Application Description:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                job.message, // This is the application message
                style: const TextStyle(fontSize: 16, color: Constants.textColor),
              ),
            ),
            const SizedBox(height: 32),

            // Action Button (e.g., Cancel Application)
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7, // Adjust width as needed
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to the Cancel Application form or show a confirmation
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CancelJobApplicationFormScreen(
                          applicationId: job.applicationId,
                          listingTitle: job.title,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600, // Red for cancel action
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Cancel Application',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
