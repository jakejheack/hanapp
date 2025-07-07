import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart'; // Your User model
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/review_service.dart';
import 'package:hanapp/models/user_review.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/services/user_service.dart'; // Import UserService
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

class ViewProfileScreen extends StatefulWidget {
  final int userId; // The ID of the user whose profile is being viewed

  const ViewProfileScreen({super.key, required this.userId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  User? _profileUser; // The user whose profile is being viewed
  bool _isLoadingProfile = true;
  String? _profileErrorMessage;

  List<Review> _reviews = [];
  bool _isLoadingReviews = false;
  String? _reviewsErrorMessage;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();

  @override
  void initState() {
    super.initState();
    _fetchUserProfileAndReviews();
  }

  Future<void> _fetchUserProfileAndReviews() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingReviews = true;
      _profileErrorMessage = null;
      _reviewsErrorMessage = null;
    });

    try {
      // --- Fetch User Profile ---
      final userResponse = await _userService.getUserProfile(widget.userId);
      if (userResponse['success']) {
        _profileUser = userResponse['user'];
      } else {
        _profileErrorMessage = userResponse['message'] ?? 'Failed to load user profile.';
        _profileUser = null; // Ensure user is null if fetching fails
      }

      // --- Fetch Reviews for the profile user ---
      final reviewResponse = await _reviewService.getReviewsForUser(userId: widget.userId);
      if (reviewResponse['success']) {
        _reviews = reviewResponse['reviews'];
        _calculateOverallRating(); // Calculate average and total from fetched reviews
      } else {
        _reviews = []; // Clear reviews on error
        _reviewsErrorMessage = reviewResponse['message'] ?? 'Failed to load reviews.';
        if (_reviewsErrorMessage!.contains('Empty response')) { // Refine message for empty responses
          _reviewsErrorMessage = 'No reviews yet for this user.';
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile or reviews: $e');
      _profileErrorMessage = 'Network error loading profile: ${e.toString()}';
      _reviewsErrorMessage = 'Network error loading reviews: ${e.toString()}';
    } finally {
      setState(() {
        _isLoadingProfile = false;
        _isLoadingReviews = false;
      });
    }
  }

  void _calculateOverallRating() {
    if (_reviews.isEmpty) {
      _averageRating = 0.0;
      _totalReviews = 0;
      return;
    }

    double sumRatings = 0.0;
    for (var review in _reviews) {
      sumRatings += review.rating;
    }
    _averageRating = sumRatings / _reviews.length;
    _totalReviews = _reviews.length;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile || _profileUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('View Profile'), backgroundColor: Constants.primaryColor, foregroundColor: Colors.white),
        body: Center(
          child: _profileErrorMessage != null
              ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _profileErrorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          )
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Profile'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: ImageUtils.createProfileImageProvider(_profileUser!.profilePictureUrl),
                    backgroundColor: Constants.lightGreyColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _profileUser!.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Constants.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profileUser!.addressDetails ?? 'Address not available',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // Ensure createdAt is not null before formatting
                    'Started on: ${DateFormat('MMM dd, yyyy').format(_profileUser!.createdAt ?? DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(Icons.star, color: Colors.amber, size: 28),
                      Text(
                        ' (${_totalReviews})',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Filter buttons for reviews
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFilterButton('All', _reviews.length),
                        _buildFilterButton('5', _reviews.where((r) => r.rating == 5).length),
                        _buildFilterButton('4', _reviews.where((r) => r.rating == 4).length),
                        _buildFilterButton('3', _reviews.where((r) => r.rating == 3).length),
                        _buildFilterButton('2', _reviews.where((r) => r.rating == 2).length),
                        _buildFilterButton('1', _reviews.where((r) => r.rating == 1).length),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- Role, Verification, and Status Row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text(_profileUser!.role.toUpperCase()),
                        avatar: Icon(_profileUser!.role == 'doer' ? Icons.handyman : Icons.person, size: 18),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      const SizedBox(width: 8),
                      if (_profileUser!.isVerified)
                        Tooltip(
                          message: 'Email Verified',
                          child: const Icon(Icons.verified, color: Colors.green, size: 22),
                        ),
                      if (_profileUser!.isIdVerified)
                        Tooltip(
                          message: 'ID Verified',
                          child: const Icon(Icons.verified_user, color: Colors.blue, size: 22),
                        ),
                      if (_profileUser!.isBadgeAcquired)
                        Tooltip(
                          message: 'Badge Acquired',
                          child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
                        ),
                      if (_profileUser!.isAvailable != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Chip(
                            label: Text(_profileUser!.isAvailable! ? 'Available' : 'Unavailable'),
                            backgroundColor: _profileUser!.isAvailable! ? Colors.green.shade50 : Colors.red.shade50,
                            avatar: Icon(_profileUser!.isAvailable! ? Icons.check_circle : Icons.cancel, color: _profileUser!.isAvailable! ? Colors.green : Colors.red, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- Contact & Info Card ---
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_profileUser!.email.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.email, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_profileUser!.email, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          if (_profileUser!.contactNumber != null && _profileUser!.contactNumber!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_profileUser!.contactNumber!, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          ],
                          if (_profileUser!.gender != null && _profileUser!.gender!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.wc, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_profileUser!.gender!, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          ],
                          if (_profileUser!.birthday != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.cake, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(DateFormat('MMM dd, yyyy').format(_profileUser!.birthday!), style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          ],
                          if (_profileUser!.totalProfit != null && _profileUser!.role == 'doer') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Total Profit: ₱${_profileUser!.totalProfit!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // --- Action Buttons ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _showSnackBar('Block user (Coming Soon)');
                          },
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('Block'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            _showSnackBar('Report user (Coming Soon)');
                          },
                          icon: const Icon(Icons.report, size: 18),
                          label: const Text('Report'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            _showSnackBar('Favorite user (Coming Soon)');
                          },
                          icon: const Icon(Icons.favorite_border, size: 18),
                          label: const Text('Favorite'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.pink.shade700,
                            side: BorderSide(color: Colors.pink.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Reviews Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Constants.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoadingReviews
                      ? const Center(child: CircularProgressIndicator())
                      : _reviewsErrorMessage != null
                      ? Center(
                    child: Text(
                      _reviewsErrorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : _reviews.isEmpty
                      ? const Center(
                    child: Text(
                      'No reviews yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    physics: const NeverScrollableScrollPhysics(), // To allow parent SingleChildScrollView to scroll
                    shrinkWrap: true,
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      return _buildReviewCard(review);
                    },
                  ),
                  const SizedBox(height: 20),
                  // "More..." button (dummy for now)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showSnackBar('More reviews (Coming Soon)');
                      },
                      child: const Text('more...', style: TextStyle(color: Constants.primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, int count) {
    // Basic styling for filter buttons
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: OutlinedButton(
        onPressed: () {
          // Implement filtering logic here based on 'label'
          _showSnackBar('Filtering by $label (${count}) - (Coming Soon)');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Constants.primaryColor,
          side: const BorderSide(color: Constants.primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: ImageUtils.createProfileImageProvider(review.listerProfilePictureUrl),
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.listerFullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(review.createdAt), // Use reviewedAt for review date
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.reviewContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  review.reviewContent,
                  style: TextStyle(fontSize: 14, color: Constants.textColor.withOpacity(0.9)),
                ),
              ),
            // NEW: Display review images if available
            if (review.reviewImageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80, // Fixed height for image scroll view
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.reviewImageUrls.length,
                  itemBuilder: (context, index) {
                    final imageUrl = review.reviewImageUrls[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                              alignment: Alignment.center,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            // Display Doer's reply if available
            if (review.doerReplyMessage != null && review.doerReplyMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doer\'s Reply:', // Indicate it's the Doer's reply
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Constants.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.doerReplyMessage!,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    if (review.repliedAt != null)
                      Text(
                        'Replied on: ${DateFormat('MMM d, yyyy').format(review.repliedAt!)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
