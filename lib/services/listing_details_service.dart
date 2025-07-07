import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hanapp/utils/api_config.dart';

class ListingDetailsService {
  Future<Map<String, dynamic>> incrementListingView({
    required int listingId,
    required String listingType, // 'PUBLIC' or 'ASAP'
  }) async {
    final url = Uri.parse(ApiConfig.incrementViewEndpoint); // Make sure this endpoint is defined in api_config.dart
    debugPrint('ListingDetailsService: Incrementing view for $listingType listing ID $listingId at URL: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'listing_id': listingId,
          'listing_type': listingType,
        }),
      );
      final responseData = json.decode(response.body);

      debugPrint('ListingDetailsService: Increment View Status Code: ${response.statusCode}');
      debugPrint('ListingDetailsService: Increment View Response Body: ${response.body}');

      return responseData;
    } catch (e) {
      debugPrint('ListingDetailsService: Error incrementing view: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
