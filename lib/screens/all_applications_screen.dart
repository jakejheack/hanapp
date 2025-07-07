import 'package:flutter/material.dart';
import 'package:hanapp/models/listing_application.dart';
import 'package:hanapp/services/listing_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:hanapp/utils/image_utils.dart';

class AllApplicationsScreen extends StatefulWidget {
  final int listingId;
  final String listingTitle;

  const AllApplicationsScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
  });

  @override
  State<AllApplicationsScreen> createState() => _AllApplicationsScreenState();
}

class _AllApplicationsScreenState extends State<AllApplicationsScreen> {
  List<Application> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ListingService _listingService = ListingService();

  @override
  void initState() {
    super.initState();
    _fetchAllApplications();
  }

  Future<void> _fetchAllApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _listingService.getApplicationsForListing(listingId: widget.listingId);
      if (response['success']) {
        setState(() {
          _applications = response['applications'];
        });
      } else {
        _errorMessage = response['message'] ?? 'Failed to load applications.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      debugPrint('Error fetching all applications: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Applications for "${widget.listingTitle}"'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 50),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchAllApplications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _applications.isEmpty
          ? Center(
        child: Text(
          'No applications found for this listing yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final application = _applications[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: ImageUtils.createProfileImageProvider(application.applicantProfilePictureUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              application.applicantName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Text(
                                  application.applicantRating.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                                const SizedBox(width: 8),
                                // Display applicant's address if available
                                if (application.applicantAddressDetails != null && application.applicantAddressDetails!.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      application.applicantAddressDetails!,
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: application.status == 'pending' ? Colors.orange.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          application.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            color: application.status == 'pending' ? Colors.orange.shade800 : Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (application.message != null && application.message!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        'Message: "${application.message!}"',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Applied: ${DateFormat('MMM dd, yyyy - hh:mm a').format(application.appliedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Implement accept logic
                            _showSnackBar('Accepting ${application.applicantName} for ${widget.listingTitle}');
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Implement reject logic
                            _showSnackBar('Rejecting ${application.applicantName} for ${widget.listingTitle}');
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
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
    );
  }
}
