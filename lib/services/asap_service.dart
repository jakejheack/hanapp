import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';

class AsapService {
  Future<Map<String, dynamic>> searchDoers({
    required int listingId,
    required double listerLatitude,
    required double listerLongitude,
    required String preferredDoerGender,
    required double maxDistance,
  }) async {
    print('AsapService: Searching for nearest and available doers...');
    print('AsapService: Max distance: ${maxDistance}km');
    print('AsapService: Preferred gender: $preferredDoerGender');
    final url = Uri.parse(ApiConfig.searchDoersEndpoint);
    print('AsapService: Searching doers at URL: $url');
    
    try {
      final requestBody = {
        'listing_id': listingId,
        'lister_latitude': listerLatitude,
        'lister_longitude': listerLongitude,
        'preferred_doer_gender': preferredDoerGender,
        'max_distance': maxDistance,
      };
      print('AsapService: Request body: $requestBody');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('AsapService: Response status code: ${response.statusCode}');
      print('AsapService: Response body: ${response.body}');
      
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'HTTP error: ${response.statusCode} - ${response.body}',
        };
      }

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      print('AsapService: Error searching doers: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> selectDoer({
    required int listingId,
    required int doerId,
    required int listerId,
  }) async {
    final url = Uri.parse(ApiConfig.selectDoerEndpoint);
    print('AsapService: Selecting doer at URL: $url');
    
    try {
      final requestBody = {
        'listing_id': listingId,
        'doer_id': doerId,
        'lister_id': listerId,
      };
      print('AsapService: Request body: $requestBody');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('AsapService: Response status code: ${response.statusCode}');
      print('AsapService: Response body: ${response.body}');
      
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'HTTP error: ${response.statusCode} - ${response.body}',
        };
      }

      final responseData = json.decode(response.body);
      print('AsapService: Parsed response data: $responseData');
      return responseData;
    } catch (e) {
      print('AsapService: Error selecting doer: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> convertToPublic({
    required int listingId,
    required int listerId,
  }) async {
    final url = Uri.parse(ApiConfig.convertToPublicEndpoint);
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'listing_id': listingId,
          'lister_id': listerId,
        }),
      );

      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
} 