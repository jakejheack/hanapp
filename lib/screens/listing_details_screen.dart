import 'package:flutter/material.dart';
import 'package:hanapp/models/listing.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/models/listing_application.dart'; // Import Application model
import 'package:hanapp/services/listing_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/screens/all_applications_screen.dart'; // NEW: Import all applications screen
import 'package:hanapp/screens/all_reviews_screen.dart'; // NEW: Import all reviews screen
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

class ListingDetailsScreen extends StatefulWidget {
  final int listingId;

  const ListingDetailsScreen({super.key, required this.listingId});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  Listing? _listing;
  List<Review> _recentReviews = []; // Show a few recent reviews
  List<Application> _applications = []; // To get the count and maybe a few
  bool _isLoading = true;
  String? _errorMessage;
  final ListingService _listingService = ListingService();

  @override
  void initState() {
    super.initState();
    _fetchListingData();
  }

  Future<void> _fetchListingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final listingResponse = await _listingService.getListingDetails(listingId: widget.listingId);
      if (!listingResponse['success']) {
        _errorMessage = listingResponse['message'] ?? 'Failed to load listing details.';
        setState(() { _isLoading = false; });
        return;
      }
      _listing = listingResponse['listing'];

      // Fetch reviews for the lister (from the fetched listing data)
      final reviewsResponse = await _listingService.getReviewsForUser(userId: _listing!.listerId);
      if (reviewsResponse['success']) {
        // Take up to 2-3 recent reviews to display on this screen
        _recentReviews = (reviewsResponse['reviews'] as List<Review>).take(3).toList();
      } else {
        debugPrint('Failed to load reviews: ${reviewsResponse['message']}');
        // Not critical, continue without reviews, but log error
      }

      // Fetch applications for the listing (primarily for count and maybe some previews)
      final applicationsResponse = await _listingService.getApplicationsForListing(listingId: widget.listingId);
      if (applicationsResponse['success']) {
        _applications = applicationsResponse['applications'];
        // The application_count is already from getListingDetails, _applications here for full list
      } else {
        debugPrint('Failed to load applications: ${applicationsResponse['message']}');
      }


    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      debugPrint('Error fetching listing data: $e');
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Listing Details'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Listing Details'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
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
                  onPressed: _fetchListingData,
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
        ),
      );
    }

    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Listing Details'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Listing details not available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing Title and Description
            Text(
              _listing!.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _listing!.description,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),

            // Lister Information
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: ImageUtils.createProfileImageProvider(_listing!.listerId.profilePictureUrl),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _listing!.listerId.listerName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 18),
                                  Text(
                                    _listing!.listerId.rating.toStringAsFixed(1),
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${_recentReviews.length} Reviews)', // Placeholder count, update with actual
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_listing!.listerId.addressDetails != null && _listing!.listerId.addressDetails!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _listing!.listerId.addressDetails!,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Applications Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Applications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.textColor),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllApplicationsScreen(
                          listingId: widget.listingId,
                          listingTitle: _listing!.title,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View all applications (${_listing!.applicationCount})', // Use fetched count
                    style: TextStyle(color: Constants.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _applications.isEmpty
                ? Center(
              child: Text('No applications yet for this listing.', style: TextStyle(color: Colors.grey.shade600)),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _applications.take(2).length, // Show up to 2 applications as preview
              itemBuilder: (context, index) {
                final app = _applications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: ImageUtils.createProfileImageProvider(app.applicantProfilePictureUrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.applicantName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                app.message ?? 'No message provided',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: app.status == 'pending' ? Colors.orange.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            app.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: app.status == 'pending' ? Colors.orange.shade800 : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Reviews Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ratings & Reviews',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.textColor),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllReviewsScreen(userId: _listing!.listerId, userName: _listing!.listerId.listerName),
                      ),
                    );
                  },
                  child: Text(
                    'View all ratings (${_recentReviews.length})', // Placeholder, update with actual total review count
                    style: TextStyle(color: Constants.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _recentReviews.isEmpty
                ? Center(
              child: Text('No reviews yet for this lister.', style: TextStyle(color: Colors.grey.shade600)),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentReviews.length,
              itemBuilder: (context, index) {
                final review = _recentReviews[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: review.reviewerProfilePictureUrl != null && review.reviewerProfilePictureUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(review.reviewerProfilePictureUrl!)
                                  : const AssetImage('assets/default_profile.png') as ImageProvider,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              review.reviewerFullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                Text(review.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          review.comment ?? 'No comment provided.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(review.createdAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension on int {
  get profilePictureUrl => null;

  String? get fullName => null;

  get rating => null;

  get addressDetails => null;

  get listerName => null;
}
