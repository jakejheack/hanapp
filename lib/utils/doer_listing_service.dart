import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/doer_listing_item.dart';

class DoerListingService {
  Future<Map<String, dynamic>> getAvailableListings({
    String categoryFilter = 'All', // 'All', 'Onsite', 'Hybrid', 'Remote'
    String searchQuery = '',
    double? distance, // NEW
    double? minBudget, // NEW
    DateTime? datePosted, // NEW
    int? currentDoerId, // NEW: To exclude current doer's own listings
  }) async {
    // Build query parameters
    Map<String, String> queryParams = {
      'category': categoryFilter,
      'search_query': searchQuery,
    };
    if (distance != null) {
      queryParams['distance'] = distance.toString();
    }
    if (minBudget != null) {
      queryParams['min_budget'] = minBudget.toString();
    }
    if (datePosted != null) {
      queryParams['date_posted'] = datePosted.toIso8601String().split('T')[0]; // Format as YYYY-MM-DD
    }
    if (currentDoerId != null) {
      queryParams['current_doer_id'] = currentDoerId.toString(); // NEW: Pass current doer ID
    }

    final uri = Uri.parse(ApiConfig.getAvailableListingsEndpoint).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        List<DoerListingItem> listings = (responseData['listings'] as List)
            .map((item) => DoerListingItem.fromJson(item))
            .toList();
        return {'success': true, 'listings': listings};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch available listings.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
