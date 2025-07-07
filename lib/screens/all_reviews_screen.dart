import 'package:flutter/material.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/services/listing_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class AllReviewsScreen extends StatefulWidget {
  final int userId; // The ID of the user whose reviews are being viewed
  final String userName; // The name of the user being reviewed

  const AllReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ListingService _listingService = ListingService();

  @override
  void initState() {
    super.initState();
    _fetchAllReviews();
  }

  Future<void> _fetchAllReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _listingService.getReviewsForUser(userId: widget.userId);
      if (response['success']) {
        setState(() {
          _reviews = response['reviews'];
        });
      } else {
        _errorMessage = response['message'] ?? 'Failed to load reviews.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      debugPrint('Error fetching all reviews: $e');
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
        title: Text('Reviews for ${widget.userName}'),
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
                onPressed: _fetchAllReviews,
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
        child: Text(
          'No reviews found for ${widget.userName} yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];
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
                  const SizedBox(height: 10),
                  Text(
                    review.comment ?? 'No comment provided.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                  ),
                  if (review.listingId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Related to Listing ID: ${review.listingId}',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                      ),
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
