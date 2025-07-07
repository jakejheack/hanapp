// Test file to verify social login with existing endpoints
// This is just for reference - you don't need to add this to your project

import 'dart:convert';
import 'package:http/http.dart' as http;

class SocialLoginTest {
  static const String baseUrl = "https://autosell.io/api";
  
  // Test creating a social user using register endpoint
  static Future<void> testSocialRegistration() async {
    print('=== Testing Social Registration ===');
    
    final testData = {
      'first_name': 'John',
      'middle_name': '',
      'last_name': 'Doe',
      'birthday': '1990-01-01',
      'address_details': '',
      'gender': '',
      'contact_number': '',
      'email': 'john.doe.test@example.com',
      'password': 'SOCIAL_LOGIN_test_firebase_uid_123',
      'role': 'user',
      'latitude': null,
      'longitude': null,
      'profile_image_base64': null,
      'profile_picture_url': 'https://example.com/photo.jpg',
      'firebase_uid': 'test_firebase_uid_123',
      'auth_provider': 'facebook',
      'is_verified': true,
      'social_registration': true,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(testData),
      );

      print('Registration Response Status: ${response.statusCode}');
      print('Registration Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          print('✅ Social registration successful!');
          return;
        }
      }
      print('❌ Social registration failed');
    } catch (e) {
      print('❌ Registration error: $e');
    }
  }

  // Test social login using login endpoint
  static Future<void> testSocialLogin() async {
    print('\n=== Testing Social Login ===');
    
    final testData = {
      'email': 'john.doe.test@example.com',
      'password': 'SOCIAL_LOGIN_test_firebase_uid_123',
      'social_login': true,
      'firebase_uid': 'test_firebase_uid_123',
      'device_info': 'Test Device',
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(testData),
      );

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          print('✅ Social login successful!');
          print('User ID: ${responseData['user']['id']}');
          print('User Role: ${responseData['user']['role']}');
          return;
        }
      }
      print('❌ Social login failed');
    } catch (e) {
      print('❌ Login error: $e');
    }
  }

  // Run all tests
  static Future<void> runTests() async {
    await testSocialRegistration();
    await Future.delayed(Duration(seconds: 2)); // Wait between tests
    await testSocialLogin();
  }
}

// To run the test:
// void main() async {
//   await SocialLoginTest.runTests();
// }
