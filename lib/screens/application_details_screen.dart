import 'package:flutter/material.dart';
import 'package:hanapp/models/listing.dart'; // Ensure correct path to your Listing model
import 'package:hanapp/utils/listing_service.dart'; // Ensure correct path to your ListingService
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/utils/image_utils.dart';

class ApplicationDetailsScreen extends StatefulWidget {
  final int listingId; // The ID of the listing related to the application

  const ApplicationDetailsScreen({super.key, required this.listingId});

  @override
  State<ApplicationDetailsScreen> createState() => _ApplicationDetailsScreenState();
}

class _ApplicationDetailsScreenState extends State<ApplicationDetailsScreen> {
  final ListingService _listingService = ListingService();
  Listing? _listing;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchListingDetails();
  }

  Future<void> _fetchListingDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _listingService.getListingDetails(widget.listingId);
      if (response['success']) {
        setState(() {
          _listing = response['listing'];
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load listing details.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141CC9),
        foregroundColor: Colors.white,
        title: const Text('Application Details'), // Title for the new screen
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _listing == null
          ? const Center(child: Text('Listing details not found.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing Title
            Text(
              _listing!.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Amount
            Text(
              '₱${_listing!.price.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 20, color: Colors.green.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Details/Description
            Text(
              _listing!.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Connect Button (example, you might want different actions here)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Example: Navigate to chat with the lister
                  // You'll need to pass appropriate arguments here
                  // For an application, this might be to view the chat related to this application
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connect / View Application Chat functionality here')),
                  );
                  // Navigator.of(context).pushNamed('/unified_chat_screen', arguments: {
                  //   'listingId': _listing!.id,
                  //   'recipientId': _listing!.listerId,
                  //   'recipientName': _listing!.listerName,
                  //   'isLister': false, // Assuming the viewer is the applicant here
                  // });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141CC9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Connect', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 24),

            // Lister's Profile Section
            const Text(
              'Posted by:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: ImageUtils.createProfileImageProvider(_listing!.listerProfilePictureUrl),
                  child: (_listing!.listerProfilePictureUrl == null || _listing!.listerProfilePictureUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 35, color: Colors.grey)
                      : null,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('ApplicationDetails: Error loading profile image: $exception');
                  },
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _listing!.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _listing!.address ?? 'N/A',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      'Started on: ${DateFormat('MMMM d, yyyy').format(_listing!.createdAt)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Reviews Section (similar to Listing Details)
            const Text(
              'Reviews:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Display average rating
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(width: 4),
                Text(
                  _listing!.listerAverageRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${_listing!.listerTotalReviews} reviews)',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // You would typically fetch and display individual reviews here
            // For now, a placeholder or a simple list if you have them in your Listing model
            if (_listing!.listerReviews != null && _listing!.listerReviews!.isNotEmpty)
              ..._listing!.listerReviews!.map((review) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
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
                              radius: 15,
                              backgroundImage: review.reviewerProfilePictureUrl != null && review.reviewerProfilePictureUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(review.reviewerProfilePictureUrl!) as ImageProvider<Object>?
                                  : null,
                              child: (review.reviewerProfilePictureUrl == null || review.reviewerProfilePictureUrl!.isEmpty)
                                  ? const Icon(Icons.person, size: 18, color: Colors.grey)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              review.reviewerFullName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(review.rating.toStringAsFixed(1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(review.comment),
                      ],
                    ),
                  ),
                ),
              )),
            if (_listing!.listerReviews == null || _listing!.listerReviews!.isEmpty)
              const Text('No reviews yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}