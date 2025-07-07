import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanapp/viewmodels/review_view_model.dart'; // Ensure correct path
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Add this dependency to pubspec.yaml

class ReviewDialog extends StatefulWidget {
  final int reviewerId;
  final int reviewedUserId;
  final int? listingId;
  final String? listingTitle;
  final String reviewedUserName; // New: Pass the name for display

  const ReviewDialog({
    super.key,
    required this.reviewerId,
    required this.reviewedUserId,
    this.listingId,
    this.listingTitle,
    required this.reviewedUserName,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 0.0,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // To make the dialog compact
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'How did it go? Please leave a review for ${widget.reviewedUserName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.person, size: 50, color: Colors.grey),
                // You can replace this with the reviewed user's actual profile picture
                // backgroundImage: CachedNetworkImageProvider(widget.reviewedUserImageUrl),
              ),
              const SizedBox(height: 10),
              Text(
                widget.reviewedUserName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'How would you rate it?',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              RatingBar.builder(
                initialRating: _rating,
                minRating: 0,
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
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'What can you say?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.all(15.0),
                ),
              ),
              const SizedBox(height: 20),
              // Placeholder for "Upload Media (optional)"
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upload Media (optional)',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  // You can add more image placeholders here
                ],
              ),
              const SizedBox(height: 30),
              _isSubmitting
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _rating == 0.0
                      ? null // Disable button if no rating is given
                      : () async {
                    setState(() {
                      _isSubmitting = true;
                    });
                    final reviewViewModel = Provider.of<ReviewViewModel>(context, listen: false);
                    final response = await reviewViewModel.submitReview(
                      reviewerId: widget.reviewerId,
                      reviewedUserId: widget.reviewedUserId,
                      listingId: widget.listingId,
                      rating: _rating,
                      comment: _commentController.text.trim(),
                    );
                    if (mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                      if (response['success']) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response['message'])),
                        );
                        Navigator.of(context).pop(); // Close the dialog
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to submit review: ${response['message']}')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141CC9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Leave Review', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Implement Save to Favorites logic here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Save to Favorites functionality not implemented yet.')),
                    );
                    // Optionally, close the dialog after saving to favorites
                    // Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF141CC9),
                    side: const BorderSide(color: Color(0xFF141CC9)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Save to Favorites', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}