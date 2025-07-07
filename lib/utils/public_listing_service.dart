import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/public_listing.dart'; // Use the updated Listing model
import 'package:hanapp/models/user.dart'; // Import User model to get current user ID
import 'package:hanapp/utils/auth_service.dart'; // To get current user

class ListingService {
  Future<Map<String, dynamic>> createListing({
    required String title,
    String? description,
    double? price,
    required String category,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String preferredDoerGender = 'Any',
    List<String>? picturesUrls,
    String? paymentMethod,
    bool isActive = true, // NEW: Default to true
    String? tags, // NEW: Tags field
  }) async {
    final url = Uri.parse(ApiConfig.createPublicListingEndpoint);
    User? currentUser = await AuthService.getUser();

    if (currentUser == null) {
      return {'success': false, 'message': 'User not logged in.'};
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lister_id': currentUser.id,
          'title': title,
          'description': description,
          'price': price,
          'category': category,
          'latitude': latitude,
          'longitude': longitude,
          'location_address': locationAddress,
          'preferred_doer_gender': preferredDoerGender,
          'pictures_urls': picturesUrls,
          'payment_method': paymentMethod,
          'is_active': isActive, // NEW
          'tags': tags, // NEW
        }),
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getListingDetails(int listingId) async {
    final url = Uri.parse('${ApiConfig.getPublicListingEndpoint}?listing_id=$listingId');
    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'listing': PublicListing.fromJson(responseData['listing'])};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch listing details.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateListing(PublicListing listing) async {
    final url = Uri.parse(ApiConfig.publicUpdateListingEndpoint);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(listing.toJson()), // Send the entire Listing object
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteListing(int listingId) async {
    final url = Uri.parse(ApiConfig.publicDeleteListingEndpoint);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'listing_id': listingId}),
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateListingStatus(int listingId, bool isActive) async {
    final url = Uri.parse(ApiConfig.updateListingStatusEndpoint);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'listing_id': listingId, 'is_active': isActive}),
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
