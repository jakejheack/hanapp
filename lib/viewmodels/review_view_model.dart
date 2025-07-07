// hanapp_flutter/lib/viewmodels/review_view_model.dart
import 'package:flutter/material.dart';
import 'package:hanapp/utils/listing_service.dart'; // Ensure correct path
import 'package:hanapp/utils/auth_service.dart'; // For fetching user details (if needed)
import 'package:hanapp/models/user.dart'; // For User model (if needed)

class ReviewViewModel extends ChangeNotifier {
  final ListingService _listingService = ListingService();
  final AuthService _authService = AuthService(); // For fetching user details

  // You might not need _reviewedUserName here if it's passed directly to the dialog
  // But keeping it for consistency if other parts of the app use it.
  String? _reviewedUserName;
  String? get reviewedUserName => _reviewedUserName;

  Future<void> fetchReviewedUserName(int reviewedUserId) async {
    final response = await _authService.getUserProfileById(userId: reviewedUserId);
    if (response['success']) {
      _reviewedUserName = (response['user'] as User).fullName;
    } else {
      _reviewedUserName = 'Unknown User'; // Fallback
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> submitReview({
    required int reviewerId,
    required int reviewedUserId,
    int? listingId,
    required double rating,
    String? comment,
    List<String>? imagePaths,
    bool saveToFavorites = false,
    bool shareToMyday = false,
    String? mydayCaption,
  }) async {
    print('ReviewViewModel: Submitting review...');
    print('  Reviewer ID: $reviewerId');
    print('  Reviewed User ID: $reviewedUserId');
    print('  Listing ID: $listingId');
    print('  Rating: $rating');
    print('  Comment: $comment');
    print('  Images: [32m${imagePaths?.length ?? 0}[0m');
    print('  Save to Favorites: $saveToFavorites');
    print('  Share to Myday: $shareToMyday');

    final response = await _listingService.submitReview(
      reviewerId: reviewerId,
      reviewedUserId: reviewedUserId,
      listingId: listingId,
      rating: rating,
      comment: comment,
      imagePaths: imagePaths,
      saveToFavorites: saveToFavorites,
      shareToMyday: shareToMyday,
      mydayCaption: mydayCaption,
    );

    if (response['success']) {
      print('ReviewViewModel: Review submitted successfully: ${response['message']}');
    } else {
      print('ReviewViewModel: Failed to submit review: ${response['message']}');
    }
    return response;
  }

  Future<void> shareReviewToMyday({
    required int reviewerId,
    required int reviewedUserId,
    int? listingId,
    required double rating,
    String? comment,
    List<String>? imagePaths,
    String? mydayCaption,
  }) async {
    await submitReview(
      reviewerId: reviewerId,
      reviewedUserId: reviewedUserId,
      listingId: listingId,
      rating: rating,
      comment: comment,
      imagePaths: imagePaths,
      saveToFavorites: false,
      shareToMyday: true,
      mydayCaption: mydayCaption,
    );
  }
}
