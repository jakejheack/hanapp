import 'package:flutter/material.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/services/review_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class UserReviewsScreen extends StatefulWidget {
  const UserReviewsScreen({super.key});

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ReviewService _reviewService = ReviewService();
  User? _currentUser;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final user = await AuthService.getUser();
    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _currentUser = user;
    });
    
    await _fetchUserReviews();
  }

  Future<void> _fetchUserReviews() async {
    if (_currentUser?.id == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _reviewService.getReviewsForUser(userId: _currentUser!.id!);
      if (response['success']) {
        setState(() {
          _reviews = response['reviews'];
          _averageRating = response['average_rating'] ?? 0.0;
          _totalReviews = response['total_reviews'] ?? 0;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load reviews.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
      debugPrint('Error fetching user reviews: $e');
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
        title: const Text('My Reviews'),
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
                          onPressed: _fetchUserReviews,
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
              : _reviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_outline, color: Colors.grey.shade400, size: 80),
                          const SizedBox(height: 16),
                          Text(
                            'No reviews yet',
                            style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You haven\'t received any reviews yet.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Summary card
                        if (_totalReviews > 0)
                          Container(
                            margin: const EdgeInsets.all(16.0),
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Constants.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Constants.primaryColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star, color: Constants.primaryColor, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Average Rating',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        _averageRating.toStringAsFixed(1),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Constants.primaryColor,
                                        ),
                                      ),
                                      Text(
                                        'Based on $_totalReviews reviews',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Reviews list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
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
                                            radius: 25,
                                            backgroundImage: review.reviewerProfilePictureUrl != null && review.reviewerProfilePictureUrl!.isNotEmpty
                                                ? CachedNetworkImageProvider(review.reviewerProfilePictureUrl!)
                                                : const AssetImage('assets/default_profile.png') as ImageProvider,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  review.reviewerFullName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                                    Text(
                                                      review.rating.toStringAsFixed(1),
                                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(review.createdAt),
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (review.comment != null && review.comment!.isNotEmpty)
                                        Text(
                                          review.comment!,
                                          style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                                        ),
                                      if (review.listingType.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Constants.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${review.listingType} Listing',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Constants.primaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Show doer reply if available
                                      if (review.doerReplyMessage != null && review.doerReplyMessage!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 12.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(12.0),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.reply, size: 16, color: Constants.primaryColor),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Your Reply',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Constants.primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  review.doerReplyMessage!,
                                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                                ),
                                                if (review.repliedAt != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
                                                    child: Text(
                                                      DateFormat('MMM dd, yyyy').format(review.repliedAt!),
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}