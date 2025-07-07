import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/combined_listing_item.dart';
import 'package:hanapp/models/user.dart'; // To get current user ID
import 'package:hanapp/utils/auth_service.dart'; // To get current user

class CombinedListingService {
  Future<Map<String, dynamic>> getCombinedListings({
    required int listerId,
    String statusFilter = 'all', // 'all', 'active', 'complete'
  }) async {
    final url = Uri.parse('${ApiConfig.getCombinedListingsEndpoint}?lister_id=$listerId&status_filter=$statusFilter');
    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        List<CombinedListingItem> listings = (responseData['listings'] as List)
            .map((item) => CombinedListingItem.fromJson(item))
            .toList();
        return {'success': true, 'listings': listings};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch combined listings.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
