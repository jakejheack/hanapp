import 'dart:io';

// Google Sign-In Configuration
class GoogleSignInConfig {
  // Client IDs from Google Cloud Console
  static const String androidClientId = '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com';
  static const String iosClientId = '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com';
  static const String webClientId = '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com';
  static const String serverClientId = '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com';

  // Scopes for Google Sign-In
  static const List<String> scopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  // Additional scopes for extended permissions (if needed)
  static const List<String> extendedScopes = [
    'https://www.googleapis.com/auth/contacts.readonly',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];

  // Google Cloud Console Project ID
  static const String projectId = 'hanapp-authentication';

  // Firebase configuration
  static const String firebaseProjectId = 'hanapp-authentication';
  static const String firebaseStorageBucket = 'hanapp-authentication.firebasestorage.app';
  static const String firebaseMessagingSenderId = '65987075200';

  // API endpoints
  static const String googleTokenInfoUrl = 'https://oauth2.googleapis.com/tokeninfo';
  static const String googleUserInfoUrl = 'https://www.googleapis.com/oauth2/v2/userinfo';
  static const String googlePeopleApiUrl = 'https://people.googleapis.com/v1';

  // Keystore configuration (for Android)
  static const String keystorePath = 'android/app/login.jks';
  static const String keystorePassword = 'loginhanapp';
  static const String keyAlias = 'test';
  static const String keyPassword = 'loginhanapp';

  // Package names
  static const String androidPackageName = 'com.example.hanapp';
  static const String iosBundleId = 'com.example.hanapp';

  // Web configuration
  static const String webAuthDomain = 'hanapp-authentication.firebaseapp.com';
  static const String webMeasurementId = 'G-SCTZ90QWM7';

  // Get the appropriate client ID based on platform
  static String getClientId() {
    if (Platform.isAndroid) {
      return androidClientId;
    } else if (Platform.isIOS) {
      return iosClientId;
    } else {
      return webClientId;
    }
  }

  // Get server client ID for backend authentication
  static String getServerClientId() {
    return serverClientId;
  }

  // Get all scopes
  static List<String> getAllScopes() {
    return [...scopes, ...extendedScopes];
  }

  // Validate configuration
  static bool isValid() {
    return androidClientId.isNotEmpty &&
           iosClientId.isNotEmpty &&
           webClientId.isNotEmpty &&
           serverClientId.isNotEmpty &&
           projectId.isNotEmpty;
  }
} 