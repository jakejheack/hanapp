# Google Sign-In Setup Guide for HanApp

This guide explains how to set up Google Sign-In for your Flutter app using Google Cloud Console, keystores, and the Flutter Google Sign-In package.

## Prerequisites

- Google Cloud Console account
- Firebase project
- Flutter development environment
- Android Studio (for Android development)
- Xcode (for iOS development)

## 1. Google Cloud Console Setup

### 1.1 Create/Configure Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project: `hanapp-authentication`
3. Enable the Google+ API and Google Sign-In API

### 1.2 Configure OAuth 2.0 Credentials

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth 2.0 Client IDs**
3. Configure for each platform:

#### Android Configuration
- **Application type**: Android
- **Package name**: `com.example.hanapp`
- **SHA-1 certificate fingerprint**: Get this from your keystore

#### iOS Configuration
- **Application type**: iOS
- **Bundle ID**: `com.example.hanapp`

#### Web Configuration
- **Application type**: Web application
- **Authorized JavaScript origins**: `https://hanapp-authentication.firebaseapp.com`
- **Authorized redirect URIs**: `https://hanapp-authentication.firebaseapp.com/__/auth/handler`

## 2. Firebase Configuration

### 2.1 Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `hanapp-authentication`
3. Add your apps (Android, iOS, Web)

### 2.2 Download Configuration Files

- **Android**: Download `google-services.json` and place in `android/app/`
- **iOS**: Download `GoogleService-Info.plist` and add to Xcode project
- **Web**: Use Firebase SDK configuration

## 3. Keystore Configuration

### 3.1 Generate Keystore (if not exists)

```bash
keytool -genkey -v -keystore android/app/login.jks -keyalg RSA -keysize 2048 -validity 10000 -alias test
```

### 3.2 Get SHA-1 Fingerprint

```bash
keytool -list -v -keystore android/app/login.jks -alias test
```

### 3.3 Update build.gradle.kts

The keystore is already configured in `android/app/build.gradle.kts`:

```kotlin
signingConfigs {
    debug {
        keyAlias 'test'
        keyPassword 'loginhanapp'
        storeFile file('login.jks')
        storePassword 'loginhanapp'
    }
}
```

## 4. Flutter Configuration

### 4.1 Dependencies

The following dependencies are already added to `pubspec.yaml`:

```yaml
dependencies:
  google_sign_in: ^7.0.0
  firebase_auth: ^4.18.0
  firebase_core: ^2.28.0
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.3
```

### 4.2 Configuration Files

#### Google Sign-In Config (`lib/utils/google_signin_config.dart`)
Contains all Google Sign-In configuration including client IDs, scopes, and API endpoints.

#### Google Auth Service (`lib/services/google_auth_service.dart`)
Handles the complete Google Sign-In flow with proper error handling and backend integration.

### 4.3 Backend Integration

The backend endpoint (`hanapp_backend/api/auth/google_auth.php`) handles:
- ID token verification
- User creation/update
- Social login linking
- JWT token generation
- Login history logging

## 5. Platform-Specific Setup

### 5.1 Android Setup

1. **google-services.json**: Already placed in `android/app/`
2. **Keystore**: Already configured in `build.gradle.kts`
3. **Permissions**: Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 5.2 iOS Setup

1. **GoogleService-Info.plist**: Add to Xcode project
2. **URL Schemes**: Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.65987075200-0iaramjhqfe82hn60h6g00ssp8il6k13</string>
        </array>
    </dict>
</array>
```

### 5.3 Web Setup

1. **Firebase Config**: Update `web/index.html` with your Firebase config
2. **Google Sign-In**: The web implementation uses Firebase Auth

## 6. Usage

### 6.1 Initialize Google Sign-In

```dart
import 'package:hanapp/services/google_auth_service.dart';

// Initialize in your app startup
await GoogleAuthService.initialize();
```

### 6.2 Sign In

```dart
final response = await GoogleAuthService.signIn(
  deviceInfo: deviceInfo,
  locationDetails: locationDetails,
);

if (response['success']) {
  // Handle successful sign-in
  final user = response['user'];
  final token = response['token'];
} else {
  // Handle error
  print(response['message']);
}
```

### 6.3 Sign Out

```dart
await GoogleAuthService.signOut();
```

## 7. Security Considerations

### 7.1 Client ID Security
- Client IDs are public and safe to include in client-side code
- Server client ID is used for backend authentication
- Never expose server secrets in client code

### 7.2 Token Verification
- Always verify ID tokens on the backend
- Use HTTPS for all API calls
- Implement proper session management

### 7.3 Keystore Security
- Keep keystore passwords secure
- Use different keystores for debug and release
- Backup keystore files securely

## 8. Troubleshooting

### 8.1 Common Issues

1. **"Sign in failed" error**
   - Check client ID configuration
   - Verify SHA-1 fingerprint in Google Cloud Console
   - Ensure Google+ API is enabled

2. **"Network error"**
   - Check internet connectivity
   - Verify API endpoints
   - Check CORS configuration

3. **"Invalid ID token"**
   - Verify client ID matches
   - Check token expiration
   - Ensure proper token format

### 8.2 Debug Information

Enable debug logging:

```dart
// Add to your app initialization
if (kDebugMode) {
  print('Google Sign-In Debug Mode Enabled');
}
```

### 8.3 Testing

1. Test on real devices (not just emulators)
2. Test with different Google accounts
3. Test sign-out and re-sign-in flows
4. Test network connectivity scenarios

## 9. Production Deployment

### 9.1 Release Keystore
Generate a release keystore:

```bash
keytool -genkey -v -keystore android/app/release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
```

### 9.2 Update build.gradle.kts
Add release signing configuration:

```kotlin
signingConfigs {
    release {
        keyAlias 'release'
        keyPassword 'your_release_password'
        storeFile file('release.jks')
        storePassword 'your_store_password'
    }
}
```

### 9.3 Environment Variables
Store sensitive information in environment variables:

```dart
// Use environment variables for sensitive data
static const String serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
```

## 10. Monitoring and Analytics

### 10.1 Firebase Analytics
Track sign-in events:

```dart
// Log sign-in events
await FirebaseAnalytics.instance.logEvent(
  name: 'google_sign_in',
  parameters: {'method': 'google'},
);
```

### 10.2 Error Tracking
Implement proper error tracking:

```dart
try {
  await GoogleAuthService.signIn();
} catch (e) {
  // Log error to your analytics service
  print('Google Sign-In Error: $e');
}
```

## Support

For issues related to:
- **Google Cloud Console**: Check Google Cloud documentation
- **Firebase**: Check Firebase documentation
- **Flutter Google Sign-In**: Check package documentation
- **App-specific issues**: Check the code comments and error messages

## Files Modified/Created

1. `lib/services/google_auth_service.dart` - New Google Sign-In service
2. `lib/utils/google_signin_config.dart` - Configuration file
3. `hanapp_backend/api/auth/google_auth.php` - Updated backend endpoint
4. `lib/screens/auth/login_screen.dart` - Updated to use new service
5. `android/app/build.gradle.kts` - Keystore configuration
6. `android/app/google-services.json` - Firebase configuration
7. `GOOGLE_SIGNIN_SETUP.md` - This setup guide 