import 'package:flutter/material.dart';
import 'package:hanapp/models/user_review.dart';
import 'package:hanapp/services/review_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart';
import 'package:hanapp/utils/image_utils.dart';
import 'package:hanapp/services/chat_service.dart';

class DoerViewReviewScreen extends StatefulWidget {
  // final int listingId;
  final int listerId; // ID of the Lister who wrote the review
  final int doerId;   // ID of the Doer (current user) who received the review

  const DoerViewReviewScreen({
    super.key,

    required this.listerId,
    required this.doerId,
  });

  @override
  State<DoerViewReviewScreen> createState() => _DoerViewReviewScreenState();
}

class _DoerViewReviewScreenState extends State<DoerViewReviewScreen> {
  Review? _listerReview;
  bool _isLoading = true;
  String? _errorMessage;
  User? _currentUser;
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmittingReply = false;

  final ReviewService _reviewService = ReviewService();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = await AuthService.getUser();
      if (_currentUser == null || _currentUser!.id != widget.doerId) {
        throw Exception("Authentication error or unauthorized access. Please log in as the correct Doer.");
      }

      await _fetchListerReview();
    } catch (e) {
      debugPrint('DoerViewReviewScreen _initializeScreen error: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchListerReview() async {
    debugPrint('DoerViewReviewScreen: Fetching Lister review...');
    try {
      final response = await _reviewService.getReviewForJob(

        listerId: widget.listerId,
        doerId: widget.doerId,
      );

      if (response['success']) {
        setState(() {
          _listerReview = response['review'];
          // If a reply already exists, pre-fill the text field
          if (_listerReview?.doerReplyMessage != null && _listerReview!.doerReplyMessage!.isNotEmpty) {
            _replyController.text = _listerReview!.doerReplyMessage!;
          }
        });
        debugPrint('DoerViewReviewScreen: Lister review fetched successfully.');
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load review.';
        });
        debugPrint('DoerViewReviewScreen: Failed to load review: $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error fetching review: $e';
      });
      debugPrint('DoerViewReviewScreen: Error fetching review: $e');
    }
  }

  Future<void> _submitDoerReply() async {
    if (_listerReview == null || _currentUser == null || _currentUser!.id == null) {
      _showSnackBar('Error: Review or user data missing to submit reply.', isError: true);
      return;
    }
    if (_replyController.text.trim().isEmpty) {
      _showSnackBar('Reply message cannot be empty.', isError: true);
      return;
    }
    // Prevent multiple replies
    if (_listerReview!.doerReplyMessage != null && _listerReview!.doerReplyMessage!.isNotEmpty) {
      _showSnackBar('You have already replied to this review.', isError: false);
      return;
    }

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      final response = await _reviewService.submitDoerReply(
        reviewId: _listerReview!.id,
        replyMessage: _replyController.text.trim(),
        doerId: _currentUser!.id!, // Current user is the Doer
      );

      if (response['success']) {
        _showSnackBar(response['message'] ?? 'Reply submitted successfully!');
        // Send reply as a chat message to the lister
        final chatService = ChatService();
        final convoResult = await chatService.createOrGetConversation(
          listerId: _listerReview!.listerId,
          doerId: _currentUser!.id!,
          listingId: _listerReview!.listingId,
          listingType: _listerReview!.listingType,
        );
        if (convoResult['success'] && convoResult['conversation_id'] != null) {
          await chatService.sendMessage(
            conversationId: convoResult['conversation_id'],
            senderId: _currentUser!.id!,
            receiverId: _listerReview!.listerId,
            messageContent: _replyController.text.trim(),
            messageType: 'text',
          );
        }
        // Optionally, update the local review object with the new reply and repliedAt
        setState(() {
          _listerReview = _listerReview!.copyWith(
            doerReplyMessage: _replyController.text.trim(),
            repliedAt: DateTime.now(),
          );
        });
      } else {
        _showSnackBar('Failed to submit reply: ${response['message']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Network error submitting reply: $e', isError: true);
      debugPrint('Error submitting reply: $e');
    } finally {
      setState(() {
        _isSubmittingReply = false;
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
        title: const Text('Review Details'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      )
          : _listerReview == null
          ? const Center(child: Text('No review found for this job.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lister\'s Review:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 10),
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
                          backgroundImage: ImageUtils.createProfileImageProvider(_listerReview!.listerProfilePictureUrl) ?? 
                              const AssetImage('assets/dashboard_image.png') as ImageProvider,
                          onBackgroundImageError: (exception, stackTrace) {
                            print('DoerViewReview: Error loading profile image: $exception');
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _listerReview!.listerFullName,
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
                            index < _listerReview!.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 24,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${_listerReview!.rating.toStringAsFixed(1)}/5.0',
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
                    if (_listerReview!.reviewContent.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _listerReview!.reviewContent,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Constants.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
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
                          'Reviewed on ${DateFormat('MMM dd, yyyy').format(_listerReview!.createdAt)}',
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
            const SizedBox(height: 24),

            // Doer's Reply Section
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
                          _listerReview!.doerReplyMessage != null && _listerReview!.doerReplyMessage!.isNotEmpty
                              ? Icons.check_circle
                              : Icons.reply,
                          color: _listerReview!.doerReplyMessage != null && _listerReview!.doerReplyMessage!.isNotEmpty
                              ? Colors.green
                              : Constants.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _listerReview!.doerReplyMessage != null && _listerReview!.doerReplyMessage!.isNotEmpty
                              ? 'Your Reply'
                              : 'Reply to this review',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Constants.textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_listerReview!.doerReplyMessage != null && _listerReview!.doerReplyMessage!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          _listerReview!.doerReplyMessage!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Constants.textColor,
                          ),
                        ),
                      ),
                      if (_listerReview!.repliedAt != null) ...[
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
                              'Replied on ${DateFormat('MMM dd, yyyy').format(_listerReview!.repliedAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
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
                          onPressed: (_isSubmittingReply || (_listerReview?.doerReplyMessage?.isNotEmpty ?? false)) ? null : _submitDoerReply,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
