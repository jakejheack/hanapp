import 'package:flutter_test/flutter_test.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Availability Status API Tests', () {
    test('should update availability status in database', () async {
      // Test the API endpoint directly
      final testUserId = 1; // Replace with a real user ID from your database
      final testAvailability = true;
      
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.updateAvailabilityEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': testUserId,
            'is_available': testAvailability,
          }),
        );
        
        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.body}');
        
        final responseData = json.decode(response.body);
        
        expect(response.statusCode, 200);
        expect(responseData['success'], true);
        expect(responseData['user']['is_available'], testAvailability);
        
      } catch (e) {
        print('API Test Error: $e');
        fail('API call failed: $e');
      }
    });

    test('should handle invalid user ID', () async {
      final invalidUserId = 99999; // Non-existent user ID
      final testAvailability = true;
      
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.updateAvailabilityEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': invalidUserId,
            'is_available': testAvailability,
          }),
        );
        
        final responseData = json.decode(response.body);
        
        expect(responseData['success'], false);
        expect(responseData['message'], contains('User not found'));
        
      } catch (e) {
        print('API Test Error: $e');
        fail('API call failed: $e');
      }
    });

    test('should handle missing parameters', () async {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.updateAvailabilityEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': 1,
            // Missing is_available parameter
          }),
        );
        
        final responseData = json.decode(response.body);
        
        expect(responseData['success'], false);
        expect(responseData['message'], contains('Missing required fields'));
        
      } catch (e) {
        print('API Test Error: $e');
        fail('API call failed: $e');
      }
    });
  });
} 