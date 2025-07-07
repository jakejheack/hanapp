import 'package:flutter/material.dart';
import 'package:hanapp/models/applicantv2.dart';
import 'package:hanapp/models/user.dart'; // For Doer's profile
import 'package:hanapp/models/review.dart'; // For Doer's reviews
import 'package:hanapp/services/profile_service.dart';
import 'package:hanapp/services/review_service.dart';
import 'package:hanapp/services/chat_service.dart'; // For 'Connect' button
import 'package:hanapp/screens/chat_screen.dart'; // For actual chat navigation
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart';
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

import '../../utils/application_service.dart';

class ListerApplicationDetailsScreen extends StatefulWidget {
  final int applicationId;
  final int doerId; // Passed from notification for initial fetching
  // final int listingId;
  const ListerApplicationDetailsScreen({
    super.key,
    required this.applicationId,
    required this.doerId,
    // required this.listingId,
  });

  @override
  State<ListerApplicationDetailsScreen> createState() => _ListerApplicationDetailsScreenState();
}

class _ListerApplicationDetailsScreenState extends State<ListerApplicationDetailsScreen> {
  Applicant? _application;
  User? _doerProfile;
  List<Review> _doerReviews = [];
  double _doerAverageRating = 0.0;
  int _doerTotalReviews = 0;

  bool _isLoading = true; // Overall loading state for the entire screen
  bool _isLoadingReviews = false; // NEW: Specific loading state for reviews section
  String? _errorMessage; // Overall error message
  String? _reviewsErrorMessage; // NEW: Specific error message for reviews section

  // State for review filtering
  int? _selectedRatingFilter; // null for 'All', 5 for '5-star', etc.

  final ApplicationService _applicationService = ApplicationService();
  final ProfileService _profileService = ProfileService();
  final ReviewService _reviewService = ReviewService();
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _fetchApplicationAndDoerDetails();
  }

  Future<void> _fetchApplicationAndDoerDetails() async {
    setState(() {
      _isLoading = true; // Set overall loading true
      _errorMessage = null;
      _isLoadingReviews = true; // Set reviews loading true initially
      _reviewsErrorMessage = null;
    });

    try {
      // 1. Fetch Application Details
      final appResponse = await _applicationService.getApplicationDetails(
        applicationId: widget.applicationId,
      );
      if (appResponse['success']) {
        _application = appResponse['application'];
      } else {
        _errorMessage = appResponse['message'] ?? 'Failed to load application details.';
        return; // Stop if application details fail
      }

      // 2. Fetch Doer Profile
      final profileResponse = await _profileService.getUserProfile(
        userId: widget.doerId, // Use the doerId passed to the screen
      );
      if (profileResponse['success']) {
        _doerProfile = profileResponse['user'];
      } else {
        _errorMessage = profileResponse['message'] ?? 'Failed to load doer profile.';
        return; // Stop if profile details fail
      }

      // 3. Fetch Doer Reviews
      final reviewsResponse = await _reviewService.getDoerReviews(
        doerId: widget.doerId,
      );
      if (reviewsResponse['success']) {
        _doerReviews = reviewsResponse['reviews'] ?? [];
        _doerAverageRating = reviewsResponse['average_rating'] ?? 0.0;
        _doerTotalReviews = reviewsResponse['total_reviews'] ?? 0;
        _reviewsErrorMessage = null; // Clear any previous review error
      } else {
        debugPrint('Failed to load doer reviews: ${reviewsResponse['message']}');
        _reviewsErrorMessage = reviewsResponse['message'] ?? 'Failed to load reviews.'; // Set specific review error
      }

    } catch (e) {
      _errorMessage = 'Network error fetching data: $e';
      debugPrint('ListerApplicationDetailsScreen _fetchApplicationAndDoerDetails error: $e');
    } finally {
      // Update states at the end
      setState(() {
        _isLoading = false; // Overall loading finished
        _isLoadingReviews = false; // Reviews loading finished
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

  // Filter reviews by rating (UI logic for your tabs)
  List<Review> _getFilteredReviews(int? rating) {
    if (rating == null) {
      return _doerReviews; // All reviews
    }
    return _doerReviews.where((review) => review.rating.toInt() == rating).toList();
  }

  // Handle 'Connect' button tap
  Future<void> _startChatWithDoer() async {
    // Ensure all necessary data is available before attempting to chat
    if (_application == null || _doerProfile == null ||
        _application!.listerId == null || _application!.doerId == null ||
        _application!.listingId == null || _application!.listingType == null ||
        _application!.listingTitle == null || _application!.id == null) {
      _showSnackBar('Error: Missing data to initiate chat.', isError: true);
      return;
    }

    // You, as the Lister, are initiating the chat with the Doer
    final int listerId = _application!.listerId!;
    final int doerId = _application!.doerId!;
    final int listingId = _application!.listingId!;
    final String listingType = _application!.listingType!;
    final String listingTitle = _application!.listingTitle!;
    final int applicationId = _application!.id!;

    setState(() {
      _isLoading = true; // Show loading while creating/getting conversation
    });

    try {
      final response = await _chatService.createOrGetConversation(
        listingId: listingId,
        listingType: listingType,
        listerId: listerId,
        doerId: doerId,
      );

      if (response['success']) {
        final int conversationId = response['conversation_id'];
        final int? receivedApplicationId = response['application_id'];

        _showSnackBar('Chat initiated!');
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversationId,
                otherUserId: doerId, // The other user in this chat is the Doer
                listingTitle: listingTitle,
                applicationId: receivedApplicationId ?? applicationId, // Use backend's appId or local
                isLister: true, // Current user (Lister) is the Lister in this chat
              ),
            ),
          );
        }
      } else {
        _showSnackBar('Failed to start chat: ${response['message']}', isError: true);
      }
    } catch (e) {
      if (e is FormatException) {
        _showSnackBar('Server sent invalid data. Check your PHP backend for errors.', isError: true);
      } else {
        _showSnackBar('Network error: $e', isError: true);
      }
      debugPrint('Error starting chat from ListerApplicationDetailsScreen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) { // Use the overall loading for the main screen state
      return Scaffold(
        appBar: AppBar(title: const Text('Application Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _application == null || _doerProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage ?? 'Failed to load application and doer details.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Display the doer's profile and application details
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Details'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Doer Profile Section (similar to ViewProfileScreen)
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: ImageUtils.createProfileImageProvider(_doerProfile!.profilePictureUrl),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _doerProfile!.fullName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Constants.textColor),
                  ),
                  const SizedBox(height: 4),
                  if (_doerProfile!.addressDetails != null && _doerProfile!.addressDetails!.isNotEmpty)
                    Text(
                      _doerProfile!.addressDetails!,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Started on: ${_doerProfile!.createdAt}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _doerAverageRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.star, color: Colors.amber, size: 28),
                      const SizedBox(width: 5),
                      Text(
                        '($_doerTotalReviews)',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 'Connect' button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _startChatWithDoer, // Disable if overall loading
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                        'Connect',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Application Message Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application Message:',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Constants.textColor),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _application!.message ?? 'No message provided.',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Reviews Section (filtered by tabs)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reviews',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Constants.textColor),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to a screen to view all reviews or manage them
                          print('View all reviews clicked');
                        },
                        child: const Text('more...', style: TextStyle(color: Constants.primaryColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Rating filter tabs (from ViewProfileScreen)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ToggleButtons(
                      isSelected: List.generate(6, (index) => _selectedRatingFilter == (index == 0 ? null : 6 - index)),
                      onPressed: (int index) {
                        setState(() {
                          _selectedRatingFilter = (index == 0 ? null : 6 - index); // 'All' at index 0, then 5, 4, 3, 2, 1
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      selectedColor: Colors.white,
                      fillColor: Constants.primaryColor,
                      color: Constants.textColor,
                      borderColor: Constants.lightGreyColor,
                      selectedBorderColor: Constants.primaryColor,
                      children: const <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('All'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('5'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('4'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('3'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('2'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('1'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Display reviews or error/loading indicator
                  _isLoadingReviews // Use the new dedicated loading flag for reviews
                      ? const Center(child: CircularProgressIndicator())
                      : _reviewsErrorMessage != null // Use dedicated error message for reviews
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _reviewsErrorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  )
                      : _getFilteredReviews(_selectedRatingFilter).isEmpty
                      ? const Center(
                    child: Text(
                      'No reviews yet for this rating.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _getFilteredReviews(_selectedRatingFilter).length,
                    itemBuilder: (context, index) {
                      final review = _getFilteredReviews(_selectedRatingFilter)[index];
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
                                    radius: 20,
                                    backgroundImage: ImageUtils.createProfileImageProvider(review.listerProfilePictureUrl) ?? 
                                        const AssetImage('assets/default_profile.png') as ImageProvider,
                                    backgroundColor: Colors.grey.shade200,
                                    onBackgroundImageError: (exception, stackTrace) {
                                      print('ListerApplicationDetails: Error loading profile image: $exception');
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      review.listerFullName ?? 'Anonymous Lister',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(review.rating.toStringAsFixed(1)),
                                      const Icon(Icons.star, color: Colors.amber, size: 18),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                review.reviewContent,
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  DateFormat('MMM dd,EEEE').format(review.createdAt),
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
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
          ],
        ),
      ),
    );
  }
}
