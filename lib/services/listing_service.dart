import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/models/listing.dart';
import 'package:hanapp/models/application.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/utils/constants.dart' as Constants;

import '../utils/api_config.dart';

class ListingService {
  final String _baseUrl = ApiConfig.baseUrl; // Ensure this is your Hostinger URL

  /// Fetches detailed information for a specific listing.
  Future<Map<String, dynamic>> getListingDetails({required int listingId}) async {
    final url = Uri.parse('$_baseUrl/api/listings/get_listing_details.php?listing_id=$listingId');
    print('ListingService: Fetching listing details for ID $listingId from $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('ListingService Get Listing Details Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        return {'success': true, 'listing': Listing.fromJson(decodedResponse['listing'])};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch listing details.'};
      }
    } catch (e) {
      print('ListingService Error fetching listing details: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetches all applications for a given listing.
  Future<Map<String, dynamic>> getApplicationsForListing({required int listingId}) async {
    final url = Uri.parse('$_baseUrl/api/listings/get_applications_for_listing.php?listing_id=$listingId');
    print('ListingService: Fetching applications for listing $listingId from $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('ListingService Get Applications Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        List<Application> applications = (decodedResponse['applications'] as List)
            .map((appJson) => Application.fromJson(appJson))
            .toList();
        return {'success': true, 'applications': applications};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch applications.'};
      }
    } catch (e) {
      print('ListingService Error fetching applications: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetches all reviews for a given user (e.g., a lister).
  Future<Map<String, dynamic>> getReviewsForUser({required int userId}) async {
    final url = Uri.parse('$_baseUrl/api/reviews/get_reviews_for_user.php?user_id=$userId');
    print('ListingService: Fetching reviews for user $userId from $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('ListingService Get Reviews Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        List<Review> reviews = (decodedResponse['reviews'] as List)
            .map((reviewJson) => Review.fromJson(reviewJson))
            .toList();
        return {'success': true, 'reviews': reviews};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to fetch reviews.'};
      }
    } catch (e) {
      print('ListingService Error fetching reviews: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<bool> hasReview({required int applicationId}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/reviews/has_review.php?application_id=$applicationId');
      print('ListingService: Checking if review exists for application $applicationId from $url');
      
      final response = await http.get(url);
      print('ListingService hasReview Response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final hasReview = data['has_review'] == true;
          print('ListingService: Review exists for application $applicationId: $hasReview');
          return hasReview;
        } else {
          print('ListingService: Backend returned success=false: ${data['message']}');
          return false;
        }
      } else {
        print('ListingService: HTTP error ${response.statusCode} when checking review');
        return false;
      }
    } catch (e) {
      print('ListingService Error checking review for application $applicationId: $e');
      return false;
    }
  }

// You might add other listing-related methods here (e.g., create, update, delete listing, apply for listing, accept application etc.)
}
