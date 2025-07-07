import 'package:flutter/material.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:hanapp/utils/listing_service.dart';
import 'package:hanapp/utils/notification_service.dart';

class RateJobScreen extends StatefulWidget {
  const RateJobScreen({super.key});

  @override
  State<RateJobScreen> createState() => _RateJobScreenState();
}

class _RateJobScreenState extends State<RateJobScreen> {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _reviewData;
  final ListingService _listingService = ListingService();
  final NotificationService _notificationService = NotificationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reviewData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (_reviewData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review data not provided.')),
      );
      Navigator.of(context).pop();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      _showSnackBar('Please provide a rating.', isError: true);
      return;
    }
    if (_reviewData == null || _reviewData!['reviewerId'] == null || _reviewData!['reviewedUserId'] == null) {
      _showSnackBar('Missing reviewer or reviewed user ID.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await _listingService.submitReview(
      reviewerId: _reviewData!['reviewerId'],
      reviewedUserId: _reviewData!['reviewedUserId'],
      listingId: _reviewData!['listingId'],
      rating: _rating,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
    );

    setState(() {
      _isLoading = false;
    });

    // if (response['success']) {
    //   _showSnackBar(response['message']);
    //   try {
    //     await _notificationService.sendNotification(
    //       receiverId: _reviewData!['reviewedUserId'],
    //       type: 'review_received',
    //       title: 'New Review!',
    //       message: 'You received a ${_rating.toStringAsFixed(1)}-star review for "${_reviewData!['listingTitle'] ?? 'a job'}".',
    //       relatedEntityId: _reviewData!['listingId'],
    //     );
    //   } catch (e) {
    //     print('Error sending review notification: $e');
    //   }
    //   Navigator.of(context).pop();
    // } else {
    //   _showSnackBar('Failed to submit review: ${response['message']}', isError: true);
    // }
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid review data.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Rate ${_reviewData!['reviewedUserName']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'How was your experience with ${_reviewData!['reviewedUserName']} for "${_reviewData!['listingTitle'] ?? 'the job'}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Add a comment (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 48),
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
              text: 'Submit Review',
              onPressed: _submitReview,
              color: const Color(0xFF34495E),
            ),
          ],
        ),
      ),
    );
  }
}