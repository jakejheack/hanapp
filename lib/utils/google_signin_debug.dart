import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hanapp/utils/google_signin_config.dart';

class GoogleSignInDebug {
  // Debug Google Sign-In configuration
  static Future<Map<String, dynamic>> debugConfiguration() async {
    final results = <String, dynamic>{};
    
    try {
      print('=== Google Sign-In Debug Information ===');
      
      // Platform information
      results['platform'] = Platform.operatingSystem;
      results['platform_version'] = Platform.operatingSystemVersion;
      
      // Configuration validation
      results['config_valid'] = GoogleSignInConfig.isValid();
      results['android_client_id'] = GoogleSignInConfig.androidClientId;
      results['ios_client_id'] = GoogleSignInConfig.iosClientId;
      results['web_client_id'] = GoogleSignInConfig.webClientId;
      results['server_client_id'] = GoogleSignInConfig.serverClientId;
      
      // Test Google Sign-In instance creation
      try {
        final googleSignIn = GoogleSignIn(
          clientId: GoogleSignInConfig.getClientId(),
          serverClientId: GoogleSignInConfig.getServerClientId(),
          scopes: GoogleSignInConfig.scopes,
        );
        results['google_signin_created'] = true;
        print('✓ GoogleSignIn instance created successfully');
      } catch (e) {
        results['google_signin_created'] = false;
        results['google_signin_error'] = e.toString();
        print('✗ GoogleSignIn instance creation failed: $e');
      }
      
      // Test basic sign-in flow (without actually signing in)
      try {
        final googleSignIn = GoogleSignIn(
          clientId: GoogleSignInConfig.getClientId(),
          serverClientId: GoogleSignInConfig.getServerClientId(),
          scopes: GoogleSignInConfig.scopes,
        );
        
        final currentUser = googleSignIn.currentUser;
        results['current_user_check'] = currentUser == null;
        print('✓ Current user check successful');
        
      } catch (e) {
        results['current_user_check'] = false;
        results['current_user_error'] = e.toString();
        print('✗ Current user check failed: $e');
      }
      
      print('=== Debug Information Complete ===');
      
    } catch (e) {
      results['debug_error'] = e.toString();
      print('✗ Debug process failed: $e');
    }
    
    return results;
  }
  
  // Print troubleshooting steps
  static void printTroubleshootingSteps() {
    print('''
=== Google Sign-In Troubleshooting Steps ===

1. **Check Google Cloud Console Configuration:**
   - Go to https://console.cloud.google.com/
   - Select your project (the one with client ID: 28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com)
   - Go to APIs & Services > Credentials
   - Find your Android OAuth 2.0 Client ID: 28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com
   - Verify the package name is: com.example.hanapp
   - Add these SHA-1 fingerprints:
     * Custom Keystore: 09:3C:25:E6:92:B5:F7:25:5E:D7:83:16:53:B9:A0:C0:6C:DB:D8:E7
     * Debug Keystore: C5:40:F0:97:79:83:AF:44:44:39:DA:CE:69:72:4C:B2:70:BB:AB:FE

2. **Enable Google Sign-In API:**
   - Go to APIs & Services > Library
   - Search for "Google Sign-In API"
   - Enable it if not already enabled

3. **Check Firebase Configuration:**
   - Verify google-services.json is in android/app/
   - Ensure Firebase project matches your Google Cloud project

4. **Test on Real Device:**
   - Google Sign-In may not work properly on emulators
   - Test on a physical Android device

5. **Check Internet Connection:**
   - Ensure device has internet access
   - Check if Google Play Services is up to date

6. **Clear App Data:**
   - Clear app data and cache
   - Uninstall and reinstall the app

7. **Check Logs:**
   - Look for detailed error messages in the console
   - Check if there are any network-related errors

=== End Troubleshooting Steps ===
''');
  }
  
  // Get SHA-1 fingerprints for easy copying
  static void printSHA1Fingerprints() {
    print('''
=== SHA-1 Fingerprints for Google Cloud Console ===

**Your Client ID:** 28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com

**Custom Keystore (login.jks):**
09:3C:25:E6:92:B5:F7:25:5E:D7:83:16:53:B9:A0:C0:6C:DB:D8:E7

**Debug Keystore:**
C5:40:F0:97:79:83:AF:44:44:39:DA:CE:69:72:4C:B2:70:BB:AB:FE

**Instructions:**
1. Go to Google Cloud Console > APIs & Services > Credentials
2. Find your Android OAuth 2.0 Client ID: 28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com
3. Edit the client ID
4. Add both SHA-1 fingerprints above
5. Save the changes
6. Wait a few minutes for changes to propagate

=== End SHA-1 Fingerprints ===
''');
  }
} 