import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/services/review_service.dart';
import 'package:intl/intl.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/user_service.dart';
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

class DoerProfileDetailsScreen extends StatefulWidget {
  final int doerId;
  final int? listingId; // Optional: if we need listing context for future features

  const DoerProfileDetailsScreen({
    super.key,
    required this.doerId,
    this.listingId,
  });

  @override
  State<DoerProfileDetailsScreen> createState() => _DoerProfileDetailsScreenState();
}

class _DoerProfileDetailsScreenState extends State<DoerProfileDetailsScreen> {
  User? _doerProfile;
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ReviewService _reviewService = ReviewService();

  @override
  void initState() {
    super.initState();
    _fetchDoerDetails();
  }

  Future<void> _fetchDoerDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch Doer Profile
      final userResponse = await AuthService().getUserProfileById(userId: widget.doerId);
      if (userResponse['success'] && userResponse['user'] != null) {
        _doerProfile = userResponse['user'];
      } else {
        _errorMessage = userResponse['message'] ?? 'Failed to load doer profile.';
      }

      // Fetch Reviews for Doer
      final reviewsResponse = await _reviewService.getReviewsForUser(userId: widget.doerId);
      if (reviewsResponse['success'] && reviewsResponse['reviews'] != null) {
        _reviews = reviewsResponse['reviews'].cast<Review>();
      } else {
        // Log or handle error if reviews fail, but don't block profile display
        print('Failed to load reviews: ${reviewsResponse['message']}');
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStarRating(double rating) {
    List<Widget> stars = [];
    for (int i = 0; i < 5; i++) {
      if (i < rating.floor()) {
        stars.add(const Icon(Icons.star, color: Colors.amber, size: 20));
      } else if (i < rating && rating - i > 0) {
        stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 20));
      } else {
        stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 20));
      }
    }
    return Row(children: stars);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doer Profile'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: Constants.screenPadding,
          child: Text(
            'Error: $_errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      )
          : SingleChildScrollView(
        padding: Constants.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doer Profile Section
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: ImageUtils.createProfileImageProvider(_doerProfile?.profilePictureUrl),
                    child: (_doerProfile?.profilePictureUrl == null || _doerProfile!.profilePictureUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _doerProfile?.fullName ?? 'Unknown Doer',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _doerProfile?.addressDetails ?? 'Address not available',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  // Assuming 'Started on' refers to when the doer joined or started their first job
                  // This data is not typically in User model, so using a placeholder or
                  // you might need to add a 'member_since' field to your User model.
                  Text(
                    'Started on: N/A', // Placeholder
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _doerProfile?.averageRating?.toStringAsFixed(1) ?? 'N/A',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      _buildStarRating(_doerProfile?.averageRating ?? 0.0),
                      const SizedBox(width: 4),
                      Text(
                        '(${_doerProfile?.reviewCount ?? 0})',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _reviews.isEmpty
                ? const Center(
              child: Text(
                'No reviews yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final review = _reviews[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: review.reviewerProfilePictureUrl != null && review.reviewerProfilePictureUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(review.reviewerProfilePictureUrl!) as ImageProvider<Object>?
                                  : null,
                              child: (review.reviewerProfilePictureUrl == null || review.reviewerProfilePictureUrl!.isEmpty)
                                  ? const Icon(Icons.person, size: 25)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.reviewerFullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  _buildStarRating(review.rating.toDouble()),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy').format(review.createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        if (review.comment != null && review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            review.comment!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
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