import 'package:flutter/material.dart';
import 'package:hanapp/models/user_review.dart';
import 'package:hanapp/services/review_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ListerReviewsScreen extends StatefulWidget {
  final int listerId;

  const ListerReviewsScreen({
    super.key,
    required this.listerId,
  });

  @override
  State<ListerReviewsScreen> createState() => _ListerReviewsScreenState();
}

class _ListerReviewsScreenState extends State<ListerReviewsScreen> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ReviewService _reviewService = ReviewService();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _reviewService.getListerReviews(listerId: widget.listerId);
      
      if (response['success']) {
        setState(() {
          _reviews = response['reviews'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load reviews';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _shareReview(Review review) {
    final String shareText = '''
🌟 My Review on HanApp

Project: ${review.projectTitle ?? 'Project #${review.applicationId}'}
Rating: ${review.rating.toStringAsFixed(1)}/5.0 ⭐
Review: ${review.reviewContent}

Reviewed on: ${_formatDate(review.createdAt)}

#HanApp #Reviews #ServiceQuality
    '''.trim();

    Share.share(
      shareText,
      subject: 'My Review on HanApp - ${review.projectTitle ?? 'Project #${review.applicationId}'}',
    );
  }

  void _shareAllReviews() {
    if (_reviews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reviews to share'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final StringBuffer shareText = StringBuffer();
    shareText.writeln('🌟 My Reviews on HanApp\n');
    
    for (int i = 0; i < _reviews.length; i++) {
      final review = _reviews[i];
      shareText.writeln('${i + 1}. Project: ${review.projectTitle ?? 'Project #${review.applicationId}'}');
      shareText.writeln('   Rating: ${review.rating.toStringAsFixed(1)}/5.0 ⭐');
      shareText.writeln('   Review: ${review.reviewContent}');
      shareText.writeln('   Date: ${_formatDate(review.createdAt)}\n');
    }
    
    shareText.writeln('Total Reviews: ${_reviews.length}');
    shareText.writeln('Average Rating: ${(_reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length).toStringAsFixed(1)}/5.0');
    shareText.writeln('\n#HanApp #Reviews #ServiceQuality');

    Share.share(
      shareText.toString(),
      subject: 'My Reviews on HanApp - ${_reviews.length} Reviews',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareAllReviews,
            tooltip: 'Share All Reviews',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
          ),
        ],
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
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReviews,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You haven\'t given any reviews for completed projects yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          return _buildReviewCard(review);
                        },
                      ),
                    ),
      floatingActionButton: _reviews.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _shareAllReviews,
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.share),
              label: const Text('Share All'),
            )
          : null,
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Doer Info and Rating
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Constants.primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    size: 25,
                    color: Constants.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Doer ID: ${review.doerId}',
                         style: const TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: Constants.textColor,
                         ),
                       ),
                       const SizedBox(height: 4),
                       if (review.projectTitle != null && review.projectTitle!.isNotEmpty)
                         Text(
                           review.projectTitle!,
                           style: const TextStyle(
                             fontSize: 15,
                             fontWeight: FontWeight.w600,
                             color: Constants.primaryColor,
                           ),
                         ),
                       const SizedBox(height: 2),
                       Text(
                         'Type: ${review.listingType}',
                         style: TextStyle(
                           fontSize: 12,
                           color: Colors.grey.shade600,
                         ),
                       ),
                     ],
                   ),
                 ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Star Rating
            Row(
              children: [
                Text(
                  'Rating: ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${review.rating.toStringAsFixed(1)}/5.0',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Review Content
            if (review.reviewContent.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  review.reviewContent,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Constants.textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Doer's Reply (if any)
            if (review.doerReplyMessage != null && review.doerReplyMessage!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Doer\'s Reply',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review.doerReplyMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Review Date, Project Info, and Share Button
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Reviewed ${_formatDate(review.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (review.applicationId != null)
                  Text(
                    'App #${review.applicationId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.share,
                    size: 16,
                    color: Constants.primaryColor,
                  ),
                  onPressed: () => _shareReview(review),
                  tooltip: 'Share this review',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 