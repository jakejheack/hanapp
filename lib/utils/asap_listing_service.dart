import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/asap_listing.dart'; // Use the new AsapListing model
import 'package:hanapp/models/user.dart'; // Import User model to get current user ID
import 'package:hanapp/utils/auth_service.dart'; // To get current user

class AsapListingService {
  Future<Map<String, dynamic>> createAsapListing({
    required String title,
    String? description,
    required double price,
    required double latitude,
    required double longitude,
    required String locationAddress,
    String preferredDoerGender = 'Any',
    List<String>? picturesUrls,
    required String paymentMethod,
    bool isActive = true, // NEW: Default to true
  }) async {
    final url = Uri.parse(ApiConfig.createAsapListingEndpoint);
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
          'latitude': latitude,
          'longitude': longitude,
          'location_address': locationAddress,
          'preferred_doer_gender': preferredDoerGender,
          'pictures_urls': picturesUrls,
          'payment_method': paymentMethod,
          'is_active': isActive, // NEW
        }),
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getAsapListingDetails(int listingId) async {
    final url = Uri.parse('${ApiConfig.getAsapListingDetailsEndpoint}?listing_id=$listingId');
    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'listing': AsapListing.fromJson(responseData['listing'])};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch ASAP listing details.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateAsapListing(AsapListing listing) async {
    final url = Uri.parse(ApiConfig.updateAsapListingEndpoint);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(listing.toJson()), // Send the entire AsapListing object
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteAsapListing(int listingId) async {
    final url = Uri.parse(ApiConfig.deleteAsapListingEndpoint);
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

  Future<Map<String, dynamic>> updateAsapListingStatus(int listingId, bool isActive) async {
    final url = Uri.parse(ApiConfig.updateAsapListingStatusEndpoint);
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
