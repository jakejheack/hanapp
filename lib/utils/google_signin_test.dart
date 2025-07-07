import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hanapp/services/google_auth_service.dart';
import 'package:hanapp/utils/google_signin_config.dart';

class GoogleSignInTest {
  // Test Google Sign-In configuration
  static Future<Map<String, dynamic>> testConfiguration() async {
    final results = <String, dynamic>{};
    
    try {
      // Test configuration validation
      results['config_valid'] = GoogleSignInConfig.isValid();
      
      // Test client IDs
      results['android_client_id'] = GoogleSignInConfig.androidClientId.isNotEmpty;
      results['ios_client_id'] = GoogleSignInConfig.iosClientId.isNotEmpty;
      results['web_client_id'] = GoogleSignInConfig.webClientId.isNotEmpty;
      results['server_client_id'] = GoogleSignInConfig.serverClientId.isNotEmpty;
      
      // Test platform-specific client ID
      results['platform_client_id'] = GoogleSignInConfig.getClientId().isNotEmpty;
      
      // Test scopes
      results['scopes_valid'] = GoogleSignInConfig.scopes.isNotEmpty;
      
      // Test keystore configuration (Android only)
      if (Platform.isAndroid) {
        final keystoreFile = File(GoogleSignInConfig.keystorePath);
        results['keystore_exists'] = keystoreFile.existsSync();
      }
      
      // Test initialization
      try {
        await GoogleAuthService.initialize();
        results['initialization_success'] = true;
      } catch (e) {
        results['initialization_success'] = false;
        results['initialization_error'] = e.toString();
      }
      
      // Test current user status
      final isSignedIn = await GoogleAuthService.isSignedIn();
      results['current_user_status'] = isSignedIn;
      
      if (kDebugMode) {
        print('Google Sign-In Configuration Test Results:');
        results.forEach((key, value) {
          print('  $key: $value');
        });
      }
      
    } catch (e) {
      results['test_error'] = e.toString();
    }
    
    return results;
  }
  
  // Test Google Sign-In flow (without actually signing in)
  static Future<Map<String, dynamic>> testSignInFlow() async {
    final results = <String, dynamic>{};
    
    try {
      // Test if service is initialized
      final isSignedIn = await GoogleAuthService.isSignedIn();
      results['service_initialized'] = true;
      results['current_sign_in_status'] = isSignedIn;
      
      // Test getting current user (should be null if not signed in)
      final currentUser = await GoogleAuthService.getCurrentUser();
      results['current_user_null'] = currentUser == null;
      
      if (kDebugMode) {
        print('Google Sign-In Flow Test Results:');
        results.forEach((key, value) {
          print('  $key: $value');
        });
      }
      
    } catch (e) {
      results['flow_test_error'] = e.toString();
    }
    
    return results;
  }
  
  // Validate configuration for specific platform
  static Map<String, dynamic> validatePlatformConfig() {
    final results = <String, dynamic>{};
    
    if (Platform.isAndroid) {
      results['platform'] = 'Android';
      results['client_id'] = GoogleSignInConfig.androidClientId;
      results['package_name'] = GoogleSignInConfig.androidPackageName;
      results['keystore_path'] = GoogleSignInConfig.keystorePath;
    } else if (Platform.isIOS) {
      results['platform'] = 'iOS';
      results['client_id'] = GoogleSignInConfig.iosClientId;
      results['bundle_id'] = GoogleSignInConfig.iosBundleId;
    } else {
      results['platform'] = 'Web';
      results['client_id'] = GoogleSignInConfig.webClientId;
    }
    
    return results;
  }
  
  // Print configuration summary
  static void printConfigurationSummary() {
    if (kDebugMode) {
      print('=== Google Sign-In Configuration Summary ===');
      print('Project ID: ${GoogleSignInConfig.projectId}');
      print('Firebase Project ID: ${GoogleSignInConfig.firebaseProjectId}');
      print('Platform: ${Platform.operatingSystem}');
      print('Client ID: ${GoogleSignInConfig.getClientId()}');
      print('Server Client ID: ${GoogleSignInConfig.getServerClientId()}');
      print('Scopes: ${GoogleSignInConfig.scopes.join(', ')}');
      print('Configuration Valid: ${GoogleSignInConfig.isValid()}');
      print('===========================================');
    }
  }
} 