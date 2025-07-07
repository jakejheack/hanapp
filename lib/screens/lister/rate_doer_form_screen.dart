
import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/auth_service.dart'; // For current user
import 'package:hanapp/services/review_service.dart'; // You'll need to create this
import 'package:image_picker/image_picker.dart'; // For image upload
import 'dart:io'; // For File

class RateDoerFormScreen extends StatefulWidget {
  final int applicationId;
  final int doerId;
  final int listerId;
  final String listingTitle;

  const RateDoerFormScreen({
    super.key,
    required this.applicationId,
    required this.doerId,
    required this.listerId,
    required this.listingTitle,
  });

  @override
  State<RateDoerFormScreen> createState() => _RateDoerFormScreenState();
}

class _RateDoerFormScreenState extends State<RateDoerFormScreen> {
  double _rating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  final List<XFile> _selectedMedia = []; // For storing selected images/videos
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;

  final ReviewService _reviewService = ReviewService(); // Initialize your review service

  Future<void> _pickMedia() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _selectedMedia.add(file);
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      _showSnackBar('Please provide a rating.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // In a real app, you might upload media first to get URLs, then send review.
      // For simplicity, this example just sends review data.
      // You'll need to adjust ReviewService.submitReview to handle media.
      final response = await _reviewService.submitReview(
        applicationId: widget.applicationId,
        listerId: widget.listerId,
        doerId: widget.doerId,
        rating: _rating,
        reviewContent: _reviewController.text.trim(),
        // mediaFiles: _selectedMedia, // Pass files if your service handles direct file upload
      );

      if (response['success']) {
        _showSnackBar(response['message'] ?? 'Review submitted successfully!');
        if (mounted) {
          // Navigate back to the dashboard or a confirmation screen
          Navigator.of(context).popUntil((route) => route.isFirst); // Pop all the way to home
          Navigator.of(context).pushReplacementNamed('/lister_dashboard'); // Or relevant dashboard
        }
      } else {
        _showSnackBar(response['message'] ?? 'Failed to submit review.', isError: true);
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e', isError: true);
      debugPrint('Error submitting review: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave a Review'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How did it go? Please leave a review for ${widget.listingTitle} to exit this page',
              style: TextStyle(fontSize: 16, color: Constants.textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 20),
            // Rating Section
            Text(
              'How would you rate it?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            // Review Text Field
            Text(
              'What can you say?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reviewController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your review here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Constants.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            // Upload Media Section
            Text(
              'Upload Media (optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      GestureDetector(
                        onTap: _pickMedia,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Icon(
                            Icons.add_a_photo,
                            color: Colors.grey.shade600,
                            size: 30,
                          ),
                        ),
                      ),
                      ..._selectedMedia.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final XFile file = entry.value;
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(file.path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removeMedia(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Supported formats: .png, .jpg, .jpeg, .mp4',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                  'Leave Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () {
                  // Action for "Save to Favorites" or skip review for now
                  // For now, let's pop this screen and go back to chat or dashboard
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst); // Pop all the way to home
                    Navigator.of(context).pushReplacementNamed('/lister_dashboard'); // Or relevant dashboard
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Constants.primaryColor,
                  side: const BorderSide(color: Constants.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Save to Favorites', // Or "Skip for now"
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
