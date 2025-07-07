import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/models/user.dart'; // Ensure correct path
import 'package:hanapp/models/review.dart'; // Import Review model
import 'package:hanapp/utils/auth_service.dart'; // For fetching user profile
import 'package:hanapp/utils/listing_service.dart'; // For fetching reviews (or a new ReviewService)
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/services/user_service.dart';
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

class UserProfileScreen extends StatefulWidget {
  final int userId; // The ID of the user whose profile is to be viewed

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  final ListingService _listingService = ListingService(); // Or ReviewService
  User? _userProfile;
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserProfileAndReviews();
  }

  Future<void> _fetchUserProfileAndReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch user profile
      final userResponse = await _authService.getUserProfileById(userId: widget.userId);
      if (userResponse['success']) {
        _userProfile = userResponse['user'];
      } else {
        _errorMessage = userResponse['message'] ?? 'Failed to load user profile.';
        setState(() { _isLoading = false; }); // Stop loading if profile fails
        return;
      }

      // Fetch reviews for this user
      final reviewsResponse = await _listingService.getReviewsForUser(widget.userId);
      if (reviewsResponse['success']) {
        _reviews = reviewsResponse['reviews'].cast<Review>();
        _reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
      } else {
        // Log error but don't block display if reviews fail
        print('Failed to load reviews: ${reviewsResponse['message']}');
        _reviews = []; // Ensure it's an empty list
      }

    } catch (e) {
      _errorMessage = 'An error occurred: $e';
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
        title: Text(_userProfile?.fullName ?? 'User Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _userProfile == null
          ? const Center(child: Text('User profile not found.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: ImageUtils.createProfileImageProvider(_userProfile!.profilePictureUrl),
                    child: (_userProfile!.profilePictureUrl == null || _userProfile!.profilePictureUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 70, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userProfile!.fullName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userProfile!.addressDetails ?? 'Address not available',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        _userProfile!.averageRating!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_userProfile!.totalReviews} reviews)',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 40, thickness: 1),
            const Text(
              'Recent Reviews:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _reviews.isEmpty
                ? const Center(child: Text('No reviews yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final review = _reviews[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
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
                              radius: 20,
                              backgroundImage: review.reviewerProfilePictureUrl != null && review.reviewerProfilePictureUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(review.reviewerProfilePictureUrl!) as ImageProvider<Object>?
                                  : null,
                              child: (review.reviewerProfilePictureUrl == null || review.reviewerProfilePictureUrl!.isEmpty)
                                  ? const Icon(Icons.person, size: 25, color: Colors.grey)
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
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(review.createdAt),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 20),
                                Text(
                                  review.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          review.comment,
                          style: const TextStyle(fontSize: 15),
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
