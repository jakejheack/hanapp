import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hanapp/models/combined_listing_item.dart';
import 'package:hanapp/utils/api_config.dart';

class CombinedListingService {
  Future<Map<String, dynamic>> fetchCombinedListings({required int listerId}) async {
    final url = Uri.parse('${ApiConfig.getCombinedListingsEndpoint}?user_id=$listerId');
    debugPrint('CombinedListingService: Fetching combined listings from URL: $url');

    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      debugPrint('CombinedListingService: Status Code: ${response.statusCode}');
      debugPrint('CombinedListingService: Response Body: ${response.body}');

      if (response.statusCode == 200 && responseData['success']) {
        List<CombinedListingItem> listings = (responseData['listings'] as List)
            .map((item) => CombinedListingItem.fromJson(item))
            .toList();

        // Extract total views and total applicants
        int totalViews = responseData['total_views'] as int? ?? 0;
        int totalApplicants = responseData['total_applicants'] as int? ?? 0;

        return {
          'success': true,
          'listings': listings,
          'total_views': totalViews,
          'total_applicants': totalApplicants,
        };
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch combined listings.'};
      }
    } catch (e) {
      debugPrint('CombinedListingService: Error fetching combined listings: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
