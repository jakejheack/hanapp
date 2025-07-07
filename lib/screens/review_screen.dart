import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanapp/viewmodels/review_view_model.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/review_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user_review.dart';
import 'package:hanapp/models/user.dart';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';

class ReviewScreen extends StatefulWidget {
  final int reviewerId;
  final int reviewedUserId;
  final int? listingId;
  final String? listingTitle;
  final String mode; // 'write' or 'view'

  const ReviewScreen({
    super.key,
    required this.reviewerId,
    required this.reviewedUserId,
    this.listingId,
    this.listingTitle,
    this.mode = 'write',
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  final List<XFile> _pickedImages = [];
  bool _saveToFavorites = false;
  bool _isSubmitting = false;

  // For view/reply mode
  Review? _review;
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmittingReply = false;
  final ReviewService _reviewService = ReviewService();
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'view') {
      _initializeViewMode();
    }
  }

  Future<void> _initializeViewMode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _currentUser = await AuthService.getUser();
      if (_currentUser == null) {
        throw Exception("Authentication error. Please log in.");
      }
      await _fetchReview();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchReview() async {
    try {
      final response = await _reviewService.getReviewForJob(
        listerId: widget.reviewerId,
        doerId: widget.reviewedUserId,
      );
      if (response['success']) {
        setState(() {
          _review = response['review'];
          if (_review?.doerReplyMessage != null && _review!.doerReplyMessage!.isNotEmpty) {
            _replyController.text = _review!.doerReplyMessage!;
          }
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load review.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error fetching review: $e';
      });
    }
  }

  Future<void> _submitDoerReply() async {
    if (_review == null || _currentUser == null || _currentUser!.id == null) {
      _showSnackBar('Error: Review or user data missing to submit reply.', isError: true);
      return;
    }
    if (_replyController.text.trim().isEmpty) {
      _showSnackBar('Reply message cannot be empty.', isError: true);
      return;
    }
    if (_review!.doerReplyMessage != null && _review!.doerReplyMessage!.isNotEmpty) {
      _showSnackBar('You have already replied to this review.', isError: false);
      return;
    }
    setState(() {
      _isSubmittingReply = true;
    });
    try {
      final response = await _reviewService.submitDoerReply(
        reviewId: _review!.id,
        replyMessage: _replyController.text.trim(),
        doerId: _currentUser!.id!,
      );
      if (response['success']) {
        _showSnackBar(response['message'] ?? 'Reply submitted successfully!');
        setState(() {
          _review = _review!.copyWith(
            doerReplyMessage: _replyController.text.trim(),
            repliedAt: DateTime.now(),
          );
        });
      } else {
        _showSnackBar('Failed to submit reply: ${response['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Network error submitting reply: $e', isError: true);
    } finally {
      setState(() {
        _isSubmittingReply = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      setState(() {
        _pickedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a star rating.')),
      );
      return;
    }
    setState(() { _isSubmitting = true; });
    final reviewViewModel = Provider.of<ReviewViewModel>(context, listen: false);
    // Convert image file paths to base64 strings
    final List<String> base64Images = [];
    for (final xfile in _pickedImages) {
      final bytes = await File(xfile.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      base64Images.add('data:image/jpeg;base64,$base64Str');
    }
    final response = await reviewViewModel.submitReview(
      reviewerId: widget.reviewerId,
      reviewedUserId: widget.reviewedUserId,
      listingId: widget.listingId,
      rating: _rating,
      comment: _commentController.text.trim(),
      imagePaths: base64Images,
      saveToFavorites: _saveToFavorites,
    );
    setState(() { _isSubmitting = false; });
    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'])),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: ${response['message']}')),
      );
    }
  }

  Future<void> _handleSubmitReviewWithShareOption() async {
    final shouldShare = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share to your social media?'),
        content: const Text('Would you like to share this review to your Facebook story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (shouldShare == true) {
      await _shareToFacebookStory();
    } else {
      await _submitReview();
    }
  }

  // Builds the review card widget for sharing
  Widget _buildShareableReviewCard() {
    return Material(
      color: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.listingTitle ?? 'Project #${widget.listingId ?? ''}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (index) => Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                )),
                const SizedBox(width: 8),
                Text('${_rating.toStringAsFixed(1)}/5.0', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _commentController.text.trim(),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (_pickedImages.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pickedImages.map((img) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(img.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )).toList(),
              ),
            if (_pickedImages.isNotEmpty) const SizedBox(height: 16),
            Text(
              'Reviewed on: ${_formatDate(DateTime.now())}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('#HanApp #Reviews #ServiceQuality', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }

  // Captures the review card as an image and shares it
  Future<void> _shareReviewCardAsImage() async {
    setState(() { _isSharing = true; });
    try {
      // Ensure the widget is built before capturing
      await Future.delayed(const Duration(milliseconds: 100));
      if (_shareCardKey.currentContext == null) {
        _showSnackBar('Unable to share: Review card is not ready.', isError: true);
        setState(() { _isSharing = false; });
        return;
      }
      final renderObject = _shareCardKey.currentContext!.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        _showSnackBar('Unable to share: Review card is not ready.', isError: true);
        setState(() { _isSharing = false; });
        return;
      }
      RenderRepaintBoundary boundary = renderObject as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/review_share_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Shared via HanApp');
    } catch (e) {
      _showSnackBar('Failed to share review image: $e', isError: true);
    } finally {
      setState(() { _isSharing = false; });
    }
  }

  Future<void> _shareToFacebookStory() async {
    setState(() { _isSharing = true; });
    if (_pickedImages.isNotEmpty) {
      // Wait for the widget to be built before capturing
      await WidgetsBinding.instance.endOfFrame;
      await _shareReviewCardAsImage();
    } else {
      final String shareText = '''
🌟 My Review on HanApp

Project: ${widget.listingTitle ?? 'Project #${widget.listingId ?? ''}'}
Rating: ${_rating.toStringAsFixed(1)}/5.0 ⭐
Review: ${_commentController.text.trim()}

Reviewed on: ${_formatDate(DateTime.now())}

#HanApp #Reviews #ServiceQuality
      '''.trim();
      await Share.share(shareText, subject: 'My Review on HanApp - ${widget.listingTitle ?? 'Project #${widget.listingId ?? ''}'}');
    }
    setState(() { _isSharing = false; });
    await _submitReview();
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
    if (widget.mode == 'write') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Leave a Review'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(
                    key: _shareCardKey,
                    child: _buildShareableReviewCard(),
                  ),
                  Text(
                    'How did it go? Please leave a review for ${widget.listingTitle ?? 'this job'}',
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
                    controller: _commentController,
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
                    'Upload Photos (optional)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Add Photos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (_pickedImages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pickedImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_pickedImages[index].path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(index),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Options Section
                  Text(
                    'Additional Options',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                  ),
                  const SizedBox(height: 10),
                  
                  // Save to Favorites
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: _saveToFavorites,
                      onChanged: (val) {
                        setState(() {
                          _saveToFavorites = val ?? false;
                        });
                      },
                      title: const Text('Save this person to my favorites'),
                      subtitle: const Text('You can easily find them later'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Submit Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmitReviewWithShareOption,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Review', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSharing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      );
    }
    if (widget.mode == 'view') {
      if (_isLoading) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Review Details'),
            backgroundColor: Constants.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (_errorMessage != null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Review Details'),
            backgroundColor: Constants.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        );
      }
      if (_review == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Review Details'),
            backgroundColor: Constants.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: const Center(child: Text('No review found.')),
        );
      }
      // Show review details and reply box if doer
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Details'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Lister Info and Rating
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lister Info Row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Constants.primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: Constants.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _review!.listerFullName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Constants.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lister',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
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
                              index < _review!.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 24,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            '${_review!.rating.toStringAsFixed(1)}/5.0',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Review Date
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reviewed on ${_formatDate(_review!.createdAt)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Review Content Card
              if (_review!.reviewContent.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.rate_review,
                              color: Constants.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Review Comment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Constants.textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _review!.reviewContent,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Constants.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Photos Section (if any)
              if (_review!.reviewImageUrls.isNotEmpty) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library,
                              color: Constants.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Photos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Constants.textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // TODO: Display images from URLs
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image,
                                color: Colors.grey.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_review!.reviewImageUrls.length} photo(s)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Reply Section
              if (_currentUser != null && _currentUser!.id == _review!.doerId)
                _review!.doerReplyMessage == null || _review!.doerReplyMessage!.isEmpty
                  ? Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  color: Constants.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reply to this review',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Constants.textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _replyController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts about this review...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Constants.primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmittingReply ? null : _submitDoerReply,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Constants.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                child: _isSubmittingReply
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text(
                                        'Submit Reply',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Your Reply',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Constants.textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                _review!.doerReplyMessage!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Constants.textColor,
                                ),
                              ),
                            ),
                            if (_review!.repliedAt != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Replied on ${_formatDate(_review!.repliedAt!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    }
    // Default fallback to satisfy non-null return type
    return Container();
  }
}
