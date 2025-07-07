import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:hanapp/utils/api_config.dart'; // Ensure correct path
import 'package:hanapp/models/user_review.dart'; // Import Review model
import 'package:hanapp/utils/constants.dart' as Constants;

class ReviewService {
  final String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> submitReview({
    required int applicationId,
    required int listerId,
    required int doerId,
    required double rating,
    String? reviewContent,
    // List<XFile>? mediaFiles, // If you plan to upload files directly via this service
  }) async {
    final url = Uri.parse('$_baseUrl/reviews/submit_review.php'); // New backend endpoint

    try {
      // For simplicity, we are sending JSON. If you have file uploads,
      // you would typically use a multipart request.
      // For now, let's assume media URLs would be handled separately or added later.
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'lister_id': listerId,
          'doer_id': doerId,
          'rating': rating,
          'review_content': reviewContent,
          // 'media_urls': mediaUrls, // If you upload media first and get URLs
        }),
      );

      final responseBody = json.decode(response.body);
      print('ReviewService Submit Review Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to submit review.'};
      }
    } catch (e) {
      print('ReviewService Error submitting review: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // NEW METHOD: Fetch reviews for a specific doer (or all reviews)
  Future<Map<String, dynamic>> getDoerReviews({required int doerId}) async {
    final url = Uri.parse('$_baseUrl/reviews/get_doer_reviews.php?doer_id=$doerId');
    print('ReviewService: Fetching reviews from URL: $url'); // Log URL

    try {
      final response = await http.get(url);
      print('ReviewService: Received status code: ${response.statusCode}'); // Log status code
      print('ReviewService: Received response headers: ${response.headers}'); // Log headers
      print('ReviewService: Received response body length: ${response.body.length}'); // Log body length

      // Critical debug: Print raw response body
      print('ReviewService: RAW RESPONSE BODY: ${response.body}');


      // Check if response body is empty before attempting to decode
      if (response.body.isEmpty) {
        print('ReviewService: Received empty response body for getDoerReviews. Returning failure.');
        return {'success': false, 'message': 'Empty response from server. Check server logs.'};
      }

      // If the body is not empty, try to decode
      final responseBody = json.decode(response.body); // This is the line that errors
      print('ReviewService: Decoded JSON response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        List<Review> reviews = (responseBody['reviews'] as List)
            .map((reviewJson) => Review.fromJson(reviewJson as Map<String, dynamic>))
            .toList();
        return {'success': true, 'reviews': reviews, 'average_rating': responseBody['average_rating'], 'total_reviews': responseBody['total_reviews']};
      } else {
        // If status code is 200 but 'success' is false (PHP error handled gracefully)
        print('ReviewService: Server returned success: false or unexpected status: ${responseBody['message']}');
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load reviews due to server logic.'};
      }
    } catch (e) {
      // This catch block handles FormatException (for invalid JSON) and other network errors.
      print('ReviewService Error fetching doer reviews: $e. This usually means invalid JSON or network issue.');
      return {'success': false, 'message': 'Network error: $e. Please check server logs for PHP errors.'};
    }
  }
  Future<Map<String, dynamic>> getReviewForJob({

    required int listerId,
    required int doerId,
  }) async {
    final url = Uri.parse('$_baseUrl/reviews/get_review_for_job.php?lister_id=$listerId&doer_id=$doerId');
    print('ReviewService: Fetching review from URL: $url');

    try {
      final response = await http.get(url);
      print('ReviewService: Received status code (getReviewForJob): ${response.statusCode}');
      print('ReviewService: RAW RESPONSE BODY (getReviewForJob): ${response.body}');

      if (response.body.isEmpty) {
        print('ReviewService: Received empty response body for getReviewForJob. Returning failure.');
        return {'success': false, 'message': 'Empty response from server for review. This often means backend PHP script outputting nothing. Check PHP error logs.'};
      }

      final responseBody = json.decode(response.body);
      print('ReviewService: Decoded JSON response (getReviewForJob): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'review': Review.fromJson(responseBody['review'])};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load review.'};
      }
    } catch (e) {
      print('ReviewService Error fetching review: $e');
      return {'success': false, 'message': 'Network error: $e. Please check server logs.'};
    }
  }

  /// Submits the Doer's reply to a specific review.
  Future<Map<String, dynamic>> submitDoerReply({
    required int reviewId,
    required String replyMessage,
    required int doerId, // Assuming doerId is needed for authorization on backend
  }) async {
    final url = Uri.parse('$_baseUrl/reviews/submit_doer_reply.php');
    print('ReviewService: Submitting reply for review ID: $reviewId');
    print('ReviewService: Full URL: $url');

    // Debug: Print outgoing request body and headers
    final requestBody = {
      'review_id': reviewId,
      'doer_reply_message': replyMessage,
      'doer_id': doerId,
    };
    
    // Test JSON encoding
    String jsonBody;
    try {
      jsonBody = json.encode(requestBody);
      print('ReviewService: JSON encoding successful');
    } catch (e) {
      print('ReviewService: JSON encoding failed: $e');
      return {'success': false, 'message': 'JSON encoding error: $e'};
    }
    
    print('ReviewService: Outgoing request body: $jsonBody');
    print('ReviewService: Outgoing headers: {"Content-Type": "application/json"}');

    // Null/empty checks
    if (reviewId == null || replyMessage.isEmpty || doerId == null) {
      print('ReviewService: Invalid payload - reviewId: $reviewId, replyMessage: $replyMessage, doerId: $doerId');
      return {'success': false, 'message': 'Invalid payload: All fields are required.'};
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );

      print('ReviewService: HTTP Status Code: ${response.statusCode}');
      print('ReviewService: Response Headers: ${response.headers}');
      print('ReviewService: Response Body Length: ${response.body.length}');
      print('ReviewService: RAW HTTP RESPONSE: ${response.body}');

      if (response.body.isEmpty) {
        print('ReviewService: Empty response body received');
        return {'success': false, 'message': 'Empty response from server. Check server logs.'};
      }

      final responseBody = json.decode(response.body);
      print('ReviewService Submit Doer Reply Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to submit reply.'};
      }
    } catch (e) {
      print('ReviewService Error submitting doer reply: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getReviewsForUser({required int userId}) async {
    final url = Uri.parse('$_baseUrl/reviews/get_user_reviews.php?user_id=$userId');
    print('ReviewService: Fetching reviews for user ID: $userId from URL: $url');

    try {
      final response = await http.get(url);
      print('ReviewService: Received status code (getReviewsForUser): ${response.statusCode}');
      print('ReviewService: RAW RESPONSE BODY (getReviewsForUser): ${response.body}'); // Crucial for debugging!

      if (response.body.isEmpty) {
        print('ReviewService: Received empty response body for getReviewsForUser. Returning failure.');
        // Provide a specific message that indicates an empty response from backend
        return {'success': false, 'message': 'Empty response from server for user reviews. This often means backend PHP script outputting nothing. Check PHP error logs for `get_user_reviews.php`.'};
      }

      final responseBody = json.decode(response.body); // This line is prone to FormatException
      print('ReviewService: Decoded JSON response (getReviewsForUser): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        List<Review> reviews = (responseBody['reviews'] as List)
            .map((reviewJson) => Review.fromJson(reviewJson as Map<String, dynamic>))
            .toList();

        // The PHP endpoint now returns average_rating and total_reviews
        double averageRating = (responseBody['average_rating'] as num?)?.toDouble() ?? 0.0;
        int totalReviews = (responseBody['total_reviews'] as num?)?.toInt() ?? 0;

        return {
          'success': true,
          'reviews': reviews,
          'average_rating': averageRating,
          'total_reviews': totalReviews,
        };
      } else {
        // If success is false, return the message from the backend
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load user reviews.'};
      }
    } catch (e) {
      print('ReviewService Error fetching reviews for user: $e');
      // Append a clear message for network/parsing errors
      return {'success': false, 'message': 'Network or parsing error fetching user reviews: $e. Please check server logs for `get_user_reviews.php`.'};
    }
  }

  // NEW METHOD: Fetch reviews given by a lister
  Future<Map<String, dynamic>> getListerReviews({required int listerId}) async {
    final url = Uri.parse('$_baseUrl/reviews/get_lister_reviews.php?lister_id=$listerId');
    print('ReviewService: Fetching reviews given by lister ID: $listerId from URL: $url');

    try {
      final response = await http.get(url);
      print('ReviewService: Received status code (getListerReviews): ${response.statusCode}');
      print('ReviewService: RAW RESPONSE BODY (getListerReviews): ${response.body}');

      if (response.body.isEmpty) {
        print('ReviewService: Received empty response body for getListerReviews. Returning failure.');
        return {'success': false, 'message': 'Empty response from server for lister reviews. Check PHP error logs for `get_lister_reviews.php`.'};
      }

      final responseBody = json.decode(response.body);
      print('ReviewService: Decoded JSON response (getListerReviews): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        List<Review> reviews = (responseBody['reviews'] as List)
            .map((reviewJson) => Review.fromJson(reviewJson as Map<String, dynamic>))
            .toList();

        double averageRating = (responseBody['average_rating'] as num?)?.toDouble() ?? 0.0;
        int totalReviews = (responseBody['total_reviews'] as num?)?.toInt() ?? 0;

        return {
          'success': true,
          'reviews': reviews,
          'average_rating': averageRating,
          'total_reviews': totalReviews,
        };
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load lister reviews.'};
      }
    } catch (e) {
      print('ReviewService Error fetching lister reviews: $e');
      return {'success': false, 'message': 'Network or parsing error fetching lister reviews: $e. Please check server logs for `get_lister_reviews.php`.'};
    }
  }
}
