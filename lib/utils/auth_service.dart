// hanapp_flutter/lib/utils/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/login_history_item.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hanapp/services/app_lifecycle_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AuthService {
  static const String _userKey = 'currentUser';
  static const String _tokenKey = 'userToken';
  static const String _roleKey = 'userRole';
  static User? _currentUser;

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  
  // Google Sign-In with web client ID for Firebase authentication
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '758079153152-loocnhnrakp60dscikq2p37q9nt5dalg.apps.googleusercontent.com',
  );

  // NEW: Facebook Auth instance
  static final FacebookAuth _facebookAuth = FacebookAuth.instance;

  // --- User/session management ---
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    _currentUser = user;
  }

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();

    // Clean up lifecycle service before clearing user data
    try {
      await AppLifecycleService.instance.onLogout();
    } catch (e) {
      print('AuthService: Error cleaning up lifecycle service: $e');
    }

    // Save the current availability status before clearing user data
    if (_currentUser != null && _currentUser!.role == 'doer') {
      await prefs.setBool('preserved_availability', _currentUser!.isAvailable ?? false);
    }

    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    _currentUser = null;
  }

  // --- Complete logout including social authentication ---
  static Future<void> logout() async {
    print('AuthService: Starting complete logout process...');

    try {
      // Clear local user data first
      await clearUser();

      // Clear secure storage
      final secureStorage = FlutterSecureStorage();
      await secureStorage.deleteAll();
      print('AuthService: Cleared secure storage');

      // Sign out from Firebase Auth
      try {
        await fb_auth.FirebaseAuth.instance.signOut();
        print('AuthService: Signed out from Firebase Auth');
      } catch (e) {
        print('AuthService: Error signing out from Firebase: $e');
      }

      // Sign out from Google
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        await googleSignIn.disconnect(); // This forces account selection on next login
        print('AuthService: Signed out and disconnected from Google');
      } catch (e) {
        print('AuthService: Error signing out from Google: $e');
      }

      // Sign out from Facebook
      try {
        final FacebookAuth facebookAuth = FacebookAuth.instance;
        await facebookAuth.logOut();
        print('AuthService: Signed out from Facebook');
      } catch (e) {
        print('AuthService: Error signing out from Facebook: $e');
      }

      print('AuthService: Complete logout successful');

    } catch (e) {
      print('AuthService: Error during logout: $e');
      throw e;
    }
  }

  static Future<void> saveUserSession(String token, dynamic userId, String? role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (userId is int) {
      await prefs.setInt('user_id', userId);
    } else if (userId is String) {
      await prefs.setString('user_id', userId);
    }
    if (role != null) await prefs.setString(_roleKey, role);
  }

  static Future<void> refreshUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonString = prefs.getString(_userKey);
    if (userJsonString != null) {
      _currentUser = User.fromJson(json.decode(userJsonString));
    } else {
      _currentUser = null;
    }
  }

  static Future<void> fetchAndSetUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userIdStr = prefs.getString('user_id');
    if (userIdStr == null) {
      _currentUser = null;
      return;
    }
    final int userId = int.parse(userIdStr);
    final url = Uri.parse(ApiConfig.getUserProfileEndpoint).replace(queryParameters: {'user_id': userId.toString()});
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          print('AuthService: Raw user data from server: ${data['user']}');
          print('AuthService: User data types:');
          final userData = data['user'];
          print('  - USER: ${userData['full_name']} (ID: ${userData['id']})');
          print('  - full_name: ${userData['full_name']} (${userData['full_name'].runtimeType})');
          print('  - verification_status: ${userData['verification_status']} (${userData['verification_status'].runtimeType})');
          print('  - badge_status: ${userData['badge_status']} (${userData['badge_status'].runtimeType})');
          print('  - role: ${userData['role']} (${userData['role'].runtimeType})');
          print('  - id_verified: ${userData['id_verified']} (${userData['id_verified'].runtimeType})');
          print('  - badge_acquired: ${userData['badge_acquired']} (${userData['badge_acquired'].runtimeType})');

          try {
            print('AuthService: About to call User.fromJson() with data: ${data['user']}');
            _currentUser = User.fromJson(data['user']);
            await prefs.setString(_userKey, json.encode(_currentUser!.toJson()));
            print('AuthService: Successfully fetched and set user data. Profile picture URL: ${_currentUser!.profilePictureUrl}');
          } catch (e, stackTrace) {
            print('AuthService: Error creating User from JSON: $e');
            print('AuthService: Raw user data causing error: ${data['user']}');
            print('AuthService: Stack trace: $stackTrace');

            // Let's check each field individually to see which one is causing the issue
            final userData = data['user'];
            print('AuthService: Debugging individual fields for ${userData['full_name']} (${userData['email']}):');
            print('  - verification_status: ${userData['verification_status']} (${userData['verification_status'].runtimeType})');
            print('  - badge_status: ${userData['badge_status']} (${userData['badge_status'].runtimeType})');
            print('  - role: ${userData['role']} (${userData['role'].runtimeType})');
            print('  - full_name: ${userData['full_name']} (${userData['full_name'].runtimeType})');
            print('  - email: ${userData['email']} (${userData['email'].runtimeType})');
            print('  - address_details: ${userData['address_details']} (${userData['address_details'].runtimeType})');
            print('  - contact_number: ${userData['contact_number']} (${userData['contact_number'].runtimeType})');
            print('  - gender: ${userData['gender']} (${userData['gender'].runtimeType})');
            print('  - birthday: ${userData['birthday']} (${userData['birthday'].runtimeType})');
            print('  - first_name: ${userData['first_name']} (${userData['first_name']?.runtimeType})');
            print('  - middle_name: ${userData['middle_name']} (${userData['middle_name']?.runtimeType})');
            print('  - last_name: ${userData['last_name']} (${userData['last_name']?.runtimeType})');

            _currentUser = null;
          }
        } else {
          _currentUser = null;
          print('AuthService: Failed to fetch user data: ${data['message']}');
        }
      } else {
        _currentUser = null;
        print('AuthService: HTTP error ${response.statusCode} when fetching user data');
      }
    } catch (e) {
      _currentUser = null;
      print('AuthService: Exception when fetching user data: $e');
    }
  }

  // --- Auth methods ---
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      // Get device information
      final deviceInfo = await _getDeviceInfo();
      
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
          'X-Requested-With': 'XMLHttpRequest',
          'X-Cache-Bust': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        body: jsonEncode({
          'email': email, 
          'password': password,
          'device_info': deviceInfo, // Send device info with login request
          '_cache_bust': DateTime.now().millisecondsSinceEpoch, // Cache busting parameter
          '_random': (DateTime.now().millisecondsSinceEpoch * 1000 + DateTime.now().microsecond).toString(), // Additional random parameter
        }),
      );
      
      // Debug logging for HTTP response
      print('AuthService: HTTP Status Code: ${response.statusCode}');
      print('AuthService: HTTP Response Headers: ${response.headers}');
      
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      
      // Debug logging
      print('AuthService: Response body: $responseBody');
      print('AuthService: Success: ${responseBody['success']}');
      print('AuthService: Error type: ${responseBody['error_type']}');
      print('AuthService: Response ID: ${responseBody['response_id']}');
      print('AuthService: Timestamp: ${responseBody['timestamp']}');
      print('AuthService: X-Response-ID header: ${response.headers['x-response-id']}');
      print('AuthService: X-Response-Time header: ${response.headers['x-response-time']}');
      
      // Check if we're getting a cached response (no response_id field or missing headers)
      if (!responseBody.containsKey('response_id') || 
          response.headers['x-response-id'] == null ||
          response.headers['x-response-time'] == null) {
        print('AuthService: WARNING - Possible cached response detected (missing response_id or headers)');
        
        // If we have a valid response body, use it regardless of cache status
        if (responseBody['success'] == true && responseBody['user'] != null) {
          print('AuthService: Using response despite missing cache headers');
          final user = User.fromJson(responseBody['user']);
          await saveUser(user);
          
          print('AuthService: User logged in successfully. Profile picture URL: ${user.profilePictureUrl}');
          
          // Restore preserved availability status for doers
          if (user.role == 'doer') {
            final preservedAvailability = await getPreservedAvailability();
            if (preservedAvailability != null && preservedAvailability != user.isAvailable) {
              await updateAvailabilityStatus(userId: user.id!, isAvailable: preservedAvailability);
              await clearPreservedAvailability();
            }
          }
          
          return responseBody;
        }
        
        // Try direct API call as fallback
        print('AuthService: Trying direct API call as fallback');
        return await _directLoginCall(email, password, deviceInfo);
      }
      
      // Check if the response indicates an error (either by status code or response body)
      if (response.statusCode >= 400 || responseBody['success'] == false) {
        // Clear any existing user data on failed login
        await clearUser();
        print('AuthService: Login failed - Status: ${response.statusCode}, Message: ${responseBody['message']}');
        return responseBody;
      }
      
      if (responseBody['success'] == true) {
        final user = User.fromJson(responseBody['user']);
        await saveUser(user);
        
        print('AuthService: User logged in successfully. Profile picture URL: ${user.profilePictureUrl}');
        
        // Restore preserved availability status for doers
        if (user.role == 'doer') {
          final preservedAvailability = await getPreservedAvailability();
          if (preservedAvailability != null && preservedAvailability != user.isAvailable) {
            await updateAvailabilityStatus(userId: user.id!, isAvailable: preservedAvailability);
            await clearPreservedAvailability();
          }
        }
      }
      
      return responseBody;
    } catch (e) {
      print('AuthService: Network error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Alternative approach: Direct API call with minimal caching
  Future<Map<String, dynamic>> _directLoginCall(String email, String password, String deviceInfo) async {
    try {
      print('AuthService: Making direct API call to bypass cache');
      
      // Create a unique URL with timestamp to bypass any URL-based caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueUrl = '${ApiConfig.loginEndpoint}?_t=$timestamp&_r=${DateTime.now().microsecond}';
      
      final response = await http.post(
        Uri.parse(uniqueUrl),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
          'X-Direct-Call': 'true',
          'X-Timestamp': timestamp.toString(),
        },
        body: jsonEncode({
          'email': email, 
          'password': password,
          'device_info': deviceInfo,
          '_direct_call': 'true',
          '_timestamp': timestamp,
        }),
      );
      
      print('AuthService: Direct call - HTTP Status Code: ${response.statusCode}');
      print('AuthService: Direct call - HTTP Response Headers: ${response.headers}');
      
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      
      print('AuthService: Direct call - Response body: $responseBody');
      
      // Process the response normally
      if (response.statusCode >= 400 || responseBody['success'] == false) {
        await clearUser();
        print('AuthService: Direct call login failed - Status: ${response.statusCode}, Message: ${responseBody['message']}');
        return responseBody;
      }
      
      if (responseBody['success'] == true) {
        final user = User.fromJson(responseBody['user']);
        await saveUser(user);
        
        print('AuthService: Direct call - User logged in successfully. Profile picture URL: ${user.profilePictureUrl}');
        
        // Restore preserved availability status for doers
        if (user.role == 'doer') {
          final preservedAvailability = await getPreservedAvailability();
          if (preservedAvailability != null && preservedAvailability != user.isAvailable) {
            await updateAvailabilityStatus(userId: user.id!, isAvailable: preservedAvailability);
            await clearPreservedAvailability();
          }
        }
      }
      
      return responseBody;
    } catch (e) {
      print('AuthService: Direct call network error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    String? middleName,
    required String lastName,
    required String birthday,
    required String addressDetails,
    required String gender,
    required String contactNumber,
    required String email,
    required String password,
    required String role,
    double? latitude,
    double? longitude,
    String? profileImageBase64,
  }) async {
    final url = Uri.parse(ApiConfig.registerEndpoint);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'first_name': firstName,
          'middle_name': middleName,
          'last_name': lastName,
          'birthday': birthday,
          'address_details': addressDetails,
          'gender': gender,
          'contact_number': contactNumber,
          'email': email,
          'password': password,
          'role': role,
          'latitude': latitude,
          'longitude': longitude,
          'profile_image_base64': profileImageBase64,
        }),
      );
      final responseData = json.decode(response.body);
      return responseData;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Location Validation for Social Sign-In (same logic as sign-up) ---
  static Future<bool> _validateLocationByCaviteProvince() async {
    try {
      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Use reverse geocoding to get province (same logic as sign-up)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];
        // Same logic as sign-up: check if administrativeArea is Cavite or Calabarzon
        final province = placemark.administrativeArea?.toLowerCase() ?? '';

        // Match sign-up logic: Calabarzon region maps to Cavite
        bool isQualified = (province == 'cavite') ||
                          (province == 'calabarzon') ||
                          (placemark.administrativeArea == 'Calabarzon');

        print('🔍 Social Sign-In Location validation: Province = ${placemark.administrativeArea}, Qualified = $isQualified');
        return isQualified;
      }

      return false;
    } catch (e) {
      print('❌ Error validating location for social sign-in: $e');
      return false;
    }
  }

  // --- Google Sign-In with Firebase Auth ---
  static Future<Map<String, dynamic>> signInWithGoogle({
    String? deviceInfo,
    String? locationDetails,
  }) async {
    try {
      // First validate location (same as sign-up logic)
      print('🔍 Validating location for Google Sign-In...');
      bool isValidLocation = await _validateLocationByCaviteProvince();
      if (!isValidLocation) {
        print('❌ Google Sign-In blocked: Location not in Cavite');
        return {
          'success': false,
          'message': "Sorry, it's currently unavailable in your area. We're planning to expand soon."
        };
      }
      print('✅ Location validation passed for Google Sign-In');

      // Sign out first to force account selection (allows user to choose different account)
      try {
        await _googleSignIn.signOut();
        print('AuthService: Signed out from Google to force account selection');
      } catch (e) {
        print('AuthService: Note - No existing Google session to sign out: $e');
      }

      // Trigger the authentication flow (will show account selection)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        return {'success': false, 'message': 'Google Sign-In cancelled.'};
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final fb_auth.UserCredential userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      
      // Get user info from Firebase
      final fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        print('Google Sign-In successful: ${firebaseUser.email}');

        // Get Firebase ID token for backend authentication
        final String? idToken = await firebaseUser.getIdToken();

        // Store/retrieve user data from backend database
        final backendResponse = await _handleSocialLoginBackend(
          provider: 'google',
          firebaseUid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          fullName: firebaseUser.displayName ?? '',
          profilePictureUrl: firebaseUser.photoURL ?? '',
          isVerified: firebaseUser.emailVerified,
          deviceInfo: deviceInfo,
        );

        if (backendResponse['success']) {
          try {
            print('AuthService: Creating User from Google backend response: ${backendResponse['user']}');
            final user = User.fromJson(backendResponse['user']);

            // Check if user profile is complete (for both new and existing users)
            bool isProfileComplete = _isUserProfileComplete(user);

            if (!isProfileComplete) {
              print('AuthService: User profile incomplete, needs completion');
              print('AuthService: User ID: ${user.id}, Email: ${user.email}');
              print('AuthService: Missing fields detected - redirecting to completion');
              return {
                'success': true,
                'message': 'Google Sign-In successful but profile incomplete',
                'user': user,
                'needs_completion': true,
                'social_user_data': backendResponse['user'],
                'is_existing_user': true // Flag to indicate this is an existing user
              };
            }

            // Check if user has a role set
            bool hasRole = user.role.isNotEmpty &&
                          (user.role == 'lister' || user.role == 'doer') &&
                          user.role != 'user';

            if (!hasRole) {
              print('AuthService: User profile complete but no role set, needs role selection');
              return {
                'success': true,
                'message': 'Google Sign-In successful but needs role selection',
                'user': user,
                'needs_role_selection': true
              };
            }

            // Store user data in secure storage
            final secureStorage = FlutterSecureStorage();
            await secureStorage.write(key: 'user_id', value: user.id.toString());
            await secureStorage.write(key: 'firebase_uid', value: firebaseUser.uid);
            await secureStorage.write(key: 'firebase_token', value: idToken ?? '');
            await secureStorage.write(key: 'user_email', value: user.email);
            await secureStorage.write(key: 'user_name', value: user.fullName);
            await secureStorage.write(key: 'user_photo', value: user.profilePictureUrl ?? '');
            await secureStorage.write(key: 'auth_provider', value: 'google');

            // Save to SharedPreferences for app compatibility
            await saveUser(user);
            await saveUserSession(idToken ?? '', user.id!, user.role);

            print('Google Sign-In successful with database integration. User ID: ${user.id}');
            return {'success': true, 'message': 'Google Sign-In successful', 'user': user};
          } catch (e, stackTrace) {
            print('AuthService: Error creating User from Google backend response: $e');
            print('AuthService: Backend response data: ${backendResponse['user']}');
            print('AuthService: Stack trace: $stackTrace');
            return {'success': false, 'message': 'Failed to parse user data: $e'};
          }
        } else {
          print('Backend integration failed: ${backendResponse['message']}');
          return {'success': false, 'message': 'Failed to store user data: ${backendResponse['message']}'};
        }
      }
      
      return {'success': false, 'message': 'Failed to get user information.'};
    } catch (e) {
      print('Google Sign-In Error: $e');
      return {'success': false, 'message': 'Google Sign-In error: $e'};
    }
  }

  // --- Simple Facebook Login Test (for debugging) ---
  static Future<Map<String, dynamic>> testFacebookLogin() async {
    try {
      print('=== Testing Facebook Login (No Firebase) ===');

      final LoginResult result = await _facebookAuth.login(
        permissions: ['email', 'public_profile'],
        loginBehavior: LoginBehavior.nativeWithFallback,
      );

      print('Facebook login result: ${result.status}');
      print('Facebook login message: ${result.message}');

      if (result.status == LoginStatus.success) {
        print('✅ Facebook login successful!');

        try {
          final userData = await _facebookAuth.getUserData(
            fields: "id,name,email,first_name,last_name,picture.width(200).height(200)"
          );
          print('User data: $userData');
          return {'success': true, 'message': 'Facebook login test successful', 'userData': userData};
        } catch (e) {
          print('Failed to get user data: $e');
          return {'success': false, 'message': 'Failed to get user data: $e'};
        }
      } else {
        print('❌ Facebook login failed: ${result.status} - ${result.message}');
        return {'success': false, 'message': 'Facebook login failed: ${result.message}'};
      }
    } catch (e) {
      print('❌ Facebook login test error: $e');
      return {'success': false, 'message': 'Facebook login test error: $e'};
    }
  }

  // --- Facebook Sign-In with Firebase Auth ---
  static Future<Map<String, dynamic>> signInWithFacebook({
    String? deviceInfo,
    String? locationDetails,
  }) async {
    // First validate location (same as sign-up logic)
    print('🔍 Validating location for Facebook Sign-In...');
    bool isValidLocation = await _validateLocationByCaviteProvince();
    if (!isValidLocation) {
      print('❌ Facebook Sign-In blocked: Location not in Cavite');
      return {
        'success': false,
        'message': "Sorry, it's currently unavailable in your area. We're planning to expand soon."
      };
    }
    print('✅ Location validation passed for Facebook Sign-In');

    try {
      print('=== Facebook Sign-In Debug ===');
      print('Starting Facebook login process...');

      // Check if Facebook SDK is initialized
      try {
        final currentAccessToken = await _facebookAuth.accessToken;
        print('Facebook SDK initialized. Current token: ${currentAccessToken != null ? 'exists' : 'none'}');

        // Always log out to force account selection (allows user to choose different account)
        print('Logging out existing Facebook session to force account selection...');
        await _facebookAuth.logOut();
      } catch (e) {
        print('Facebook SDK initialization check failed: $e');
        return {'success': false, 'message': 'Facebook SDK not properly initialized'};
      }

      // Check if Facebook app is installed
      print('Checking Facebook app availability...');

      // Step 1: Login with Facebook to get access token
      LoginResult result;

      // Step 1: Login with Facebook to get access token
      print('Attempting Facebook login...');
      try {
        result = await _facebookAuth.login(
          permissions: ['email', 'public_profile'],
          loginBehavior: LoginBehavior.nativeWithFallback, // Use native with fallback for better compatibility
        ).timeout(Duration(seconds: 60)); // Add timeout for login
        print('Facebook login call completed');
      } catch (e) {
        print('❌ Facebook login call failed: $e');
        if (e.toString().contains('timeout')) {
          return {'success': false, 'message': 'Facebook login timed out. Please try again.'};
        }
        return {'success': false, 'message': 'Facebook login failed: $e'};
      }

      print('Facebook login result status: ${result.status}');
      print('Facebook login result message: ${result.message}');

      // Handle different login statuses
      if (result.status == LoginStatus.cancelled) {
        print('Facebook login was cancelled by user');
        return {'success': false, 'message': 'Facebook login was cancelled'};
      } else if (result.status == LoginStatus.failed) {
        print('Facebook login failed: ${result.message}');
        return {'success': false, 'message': 'Facebook login failed: ${result.message}'};
      } else if (result.status == LoginStatus.operationInProgress) {
        print('Facebook login operation already in progress');
        return {'success': false, 'message': 'Facebook login already in progress'};
      }

      if (result.status == LoginStatus.success) {
        print('✅ Facebook login successful!');
        print('Access token: ${result.accessToken?.token?.substring(0, 20)}...');
        print('Access token expires at: ${result.accessToken?.expires}');
        print('User ID: ${result.accessToken?.userId}');
        print('Granted permissions: ${result.accessToken?.grantedPermissions}');
        print('Declined permissions: ${result.accessToken?.declinedPermissions}');

        // Step 2: Get user data from Facebook to verify token
        Map<String, dynamic> userData;
        try {
          userData = await _facebookAuth.getUserData(
            fields: "id,name,email,first_name,last_name,picture.width(200).height(200)"
          );
          print('✅ Facebook user data retrieved successfully');
          print('Available fields: ${userData.keys.toList()}');
          print('User email: ${userData['email']}');
          print('User name: ${userData['name']}');
          print('User ID: ${userData['id']}');
          print('Profile picture: ${userData['picture']?['data']?['url']}');

          // Handle missing email field
          if (userData['email'] == null || userData['email'].toString().isEmpty) {
            print('❌ Email not available from Facebook');
            print('Using Facebook ID as fallback email for app registration...');
            userData['email'] = '${userData['id']}@facebook.hanapp.temp';
            print('⚠️ Using temporary email: ${userData['email']}');
          } else {
            print('✅ Email received from Facebook: ${userData['email']}');
          }
        } catch (e) {
          print('❌ Failed to get Facebook user data: $e');
          return {'success': false, 'message': 'Failed to retrieve Facebook user information: $e'};
        }

        // Step 3: Create Firebase credential from Facebook access token (following Firebase docs)
        print('Creating Firebase credential with Facebook access token...');
        print('Email to be used: ${userData['email']}');
        final fb_auth.AuthCredential facebookAuthCredential =
            fb_auth.FacebookAuthProvider.credential(result.accessToken!.token);
        print('Firebase credential created successfully');

        // Step 4: Sign in to Firebase with Facebook credential (following Firebase docs)
        print('Signing in to Firebase with Facebook credential...');

        try {
          final fb_auth.UserCredential userCredential = await fb_auth.FirebaseAuth.instance
              .signInWithCredential(facebookAuthCredential);

          print('✅ Firebase signInWithCredential: SUCCESS');

          if (userCredential.user != null) {
            return await _handleFirebaseAuthSuccess(userCredential, userData, deviceInfo);
          } else {
            print('❌ Firebase user is null after successful authentication');
            return {'success': false, 'message': 'Firebase authentication failed - no user data'};
          }
        } catch (e) {
          print('❌ Firebase signInWithCredential: FAILED');
          print('Error: $e');
          return {'success': false, 'message': 'Firebase authentication failed: $e'};
        }
      } else {
        return {'success': false, 'message': 'Failed to get Facebook user information.'};
      }
    } catch (e) {
      print('❌ Facebook Sign-In failed: $e');
      return {'success': false, 'message': 'Facebook Sign-In failed: $e'};
    }
  }

  // Helper method to handle successful Firebase authentication
  static Future<Map<String, dynamic>> _handleFirebaseAuthSuccess(
    fb_auth.UserCredential userCredential,
    Map<String, dynamic> userData,
    String? deviceInfo,
  ) async {
    final fb_auth.User firebaseUser = userCredential.user!;

    print('✅ Firebase Facebook Sign-In successful!');
    print('Firebase User ID: ${firebaseUser.uid}');
    print('Firebase Email: ${firebaseUser.email}');
    print('Firebase Display Name: ${firebaseUser.displayName}');
    print('Firebase Photo URL: ${firebaseUser.photoURL}');

    // Get Firebase ID token for backend authentication
    final String? idToken = await firebaseUser.getIdToken();
    print('Firebase ID Token obtained: ${idToken?.substring(0, 20)}...');

    // Step 5: Store/retrieve user data from backend database using Firebase user info
    print('🔄 Integrating with backend database...');
    print('Using email: ${firebaseUser.email ?? userData['email']}');
    print('Using name: ${firebaseUser.displayName ?? userData['name']}');

    // Combine first and last names from Facebook data into fullName for backend
    final String firstName = userData['first_name'] ?? userData['name']?.split(' ').first ?? 'Facebook';
    final String lastName = userData['last_name'] ?? userData['name']?.split(' ').skip(1).join(' ') ?? 'User';
    final String fullName = '$firstName $lastName'.trim();
    final String email = firebaseUser.email ?? userData['email'] ?? '${userData['id']}@facebook.hanapp.temp';

    final backendResponse = await _handleSocialLoginBackend(
      provider: 'facebook',
      firebaseUid: firebaseUser.uid,
      email: email,
      fullName: fullName,
      profilePictureUrl: firebaseUser.photoURL ?? userData['picture']?['data']?['url'] ?? '',
      isVerified: firebaseUser.emailVerified,
      deviceInfo: deviceInfo,
    );

    print('Backend response: ${backendResponse['success'] ? 'SUCCESS' : 'FAILED'}');
    if (!backendResponse['success']) {
      print('Backend error: ${backendResponse['message']}');
      throw Exception('Backend integration failed: ${backendResponse['message']}');
    }

    print('AuthService: Creating User from Facebook backend response: ${backendResponse['user']}');
    final user = User.fromJson(backendResponse['user']);

    // Check if user profile is complete (for both new and existing users)
    bool isProfileComplete = _isUserProfileComplete(user);

    if (!isProfileComplete) {
      print('AuthService: Facebook user profile incomplete, needs completion');
      print('AuthService: User ID: ${user.id}, Email: ${user.email}');
      print('AuthService: Missing fields detected - redirecting to completion');
      return {
        'success': true,
        'message': 'Facebook Sign-In successful but profile incomplete',
        'user': user,
        'needs_completion': true,
        'social_user_data': backendResponse['user'],
        'is_existing_user': true // Flag to indicate this is an existing user
      };
    }

    // Check if user has a role set
    bool hasRole = user.role.isNotEmpty &&
                  (user.role == 'lister' || user.role == 'doer') &&
                  user.role != 'user';

    if (!hasRole) {
      print('AuthService: Facebook user profile complete but no role set, needs role selection');
      return {
        'success': true,
        'message': 'Facebook Sign-In successful but needs role selection',
        'user': user,
        'needs_role_selection': true
      };
    }

    // Store user data in secure storage
    final secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'user_id', value: user.id.toString());
    await secureStorage.write(key: 'firebase_uid', value: firebaseUser.uid);
    await secureStorage.write(key: 'firebase_token', value: idToken ?? '');
    await secureStorage.write(key: 'user_email', value: user.email);
    await secureStorage.write(key: 'user_name', value: user.fullName);
    await secureStorage.write(key: 'user_photo', value: user.profilePictureUrl ?? '');
    await secureStorage.write(key: 'auth_provider', value: 'facebook');

    // Save to SharedPreferences for app compatibility
    await saveUser(user);
    await saveUserSession(idToken ?? '', user.id!, user.role);

    print('🎉 Facebook Sign-In COMPLETE! User logged into HanApp successfully!');
    print('User ID: ${user.id}');
    print('User Email: ${user.email}');
    print('User Role: ${user.role}');
    print('User Name: ${user.fullName}');

    return {'success': true, 'message': 'Facebook Sign-In successful', 'user': user};
  }

  // --- Helper method for Facebook token backend integration ---
  static Future<Map<String, dynamic>> _sendFacebookTokenToBackend({
    required String accessToken,
    String? deviceInfo,
    String? locationDetails,
  }) async {
    try {
      print('=== Sending Facebook token to backend ===');
      print('Access token: ${accessToken.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/facebook_auth.php'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
        },
        body: jsonEncode({
          'access_token': accessToken,
          'device_info': deviceInfo ?? await _getDeviceInfo(),
          'location_details': locationDetails,
        }),
      );

      print('Facebook backend response status: ${response.statusCode}');
      print('Facebook backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('Facebook backend error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Backend authentication failed: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Facebook backend integration error: $e');
      return {
        'success': false,
        'message': 'Failed to authenticate with backend: $e'
      };
    }
  }

  // --- Helper method for social login backend integration using existing endpoints ---
  static Future<Map<String, dynamic>> _handleSocialLoginBackend({
    required String provider,
    required String firebaseUid,
    required String email,
    required String fullName,
    String? profilePictureUrl,
    bool isVerified = false,
    String? deviceInfo,
    String? firstName,
    String? lastName,
  }) async {
    try {
      print('=== Social Login Backend Integration ===');
      print('Provider: $provider');
      print('Firebase UID: $firebaseUid');
      print('Email: $email');
      print('Full Name: $fullName');

      // Step 1: Try to login with existing email to check if user exists
      final loginResponse = await _attemptSocialLogin(email, firebaseUid, deviceInfo);

      if (loginResponse['success']) {
        print('Existing user found, logged in successfully');
        return loginResponse;
      }

      // Step 2: If login failed, try to create new user
      print('User not found, creating new account...');
      final registerResponse = await _createSocialUser(
        provider: provider,
        firebaseUid: firebaseUid,
        email: email,
        fullName: fullName,
        profilePictureUrl: profilePictureUrl,
        isVerified: isVerified,
        deviceInfo: deviceInfo,
      );

      if (registerResponse['success']) {
        print('New user created successfully');
        return registerResponse;
      } else if (registerResponse['message'].contains('already registered')) {
        // Step 3: If email exists but social login failed, update existing user with social info
        print('Email exists, updating user with social login info...');
        final updateResponse = await _updateExistingUserWithSocialInfo(
          email: email,
          provider: provider,
          firebaseUid: firebaseUid,
          fullName: fullName,
          profilePictureUrl: profilePictureUrl,
          deviceInfo: deviceInfo,
        );
        return updateResponse;
      } else {
        print('Failed to create new user: ${registerResponse['message']}');
        return registerResponse;
      }

    } catch (e) {
      print('Social login backend error: $e');
      return {
        'success': false,
        'message': 'Network error during backend integration: $e'
      };
    }
  }

  // Helper method to attempt login for existing social users
  static Future<Map<String, dynamic>> _attemptSocialLogin(String email, String firebaseUid, String? deviceInfo) async {
    try {
      print('Attempting social login for existing user...');

      // Try social login with firebase_uid
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
        },
        body: jsonEncode({
          'email': email,
          'password': 'SOCIAL_LOGIN_$firebaseUid', // Special password for social users
          'device_info': deviceInfo ?? await _getDeviceInfo(),
          'social_login': true, // Flag to indicate this is a social login attempt
          'firebase_uid': firebaseUid,
        }),
      );

      print('Social login response status: ${response.statusCode}');
      print('Social login response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        if (responseBody['success']) {
          print('Social login successful for existing user');
          return responseBody;
        } else {
          print('Social login failed: ${responseBody['message']}');
          return responseBody;
        }
      } else {
        print('Social login HTTP error: ${response.statusCode}');
        return {'success': false, 'message': 'Login attempt failed with status ${response.statusCode}'};
      }
    } catch (e) {
      print('Social login exception: $e');
      return {'success': false, 'message': 'Login attempt error: $e'};
    }
  }

  // Helper method to create new social user using existing register endpoint
  static Future<Map<String, dynamic>> _createSocialUser({
    required String provider,
    required String firebaseUid,
    required String email,
    required String fullName,
    String? profilePictureUrl,
    bool isVerified = false,
    String? deviceInfo,
  }) async {
    try {
      // Split full name into first and last name
      List<String> nameParts = fullName.trim().split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts[0] : 'User';
      String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Get user's current location
      double? latitude;
      double? longitude;

      try {
        final locationData = await _getCurrentLocation();
        latitude = locationData['latitude'];
        longitude = locationData['longitude'];
        print('Got user location: $latitude, $longitude');
      } catch (e) {
        print('Failed to get location: $e');
        // Use default coordinates if location fails
        latitude = 0.0;
        longitude = 0.0;
      }

      // Use existing register endpoint with social user data
      final response = await http.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'first_name': firstName,
          'middle_name': '', // Empty for social users
          'last_name': lastName,
          'birthday': '1990-01-01', // Default birthday for social users
          'address_details': '', // Empty for social users, can be filled later
          'gender': '', // Empty for social users, can be filled later
          'contact_number': '', // Empty for social users, can be filled later
          'email': email,
          'password': 'SOCIAL_LOGIN_$firebaseUid', // Special password for social users
          'role': 'user', // Default role, user will select later
          'latitude': latitude, // User's current latitude
          'longitude': longitude, // User's current longitude
          'profile_image_base64': null, // We'll use the URL instead
          'profile_picture_url': profilePictureUrl, // Social media profile picture
          'firebase_uid': firebaseUid, // Firebase UID for linking
          'auth_provider': provider, // 'facebook' or 'google'
          'is_verified': isVerified,
          'social_registration': true, // Flag to indicate this is social registration
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        return responseBody;
      } else {
        return {
          'success': false,
          'message': 'Registration failed: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration error: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendPasswordResetEmailEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyPasswordResetCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyPasswordResetCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resetPasswordWithCode(String email, String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPasswordWithCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyEmail({required String email, required String code}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyEmailEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resendVerificationCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Profile management ---
  static Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    String? fullName,
    String? email,
    String? contactNumber,
    String? addressDetails,
    double? latitude,
    double? longitude,
    String? profileImageBase64,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.updateProfileEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'full_name': fullName,
          'email': email,
          'contact_number': contactNumber,
          'address_details': addressDetails,
          'latitude': latitude,
          'longitude': longitude,
          'profile_image_base64': profileImageBase64,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- User profile by ID ---
  Future<Map<String, dynamic>> getUserProfileById({required int userId}) async {
    try {
      final url = Uri.parse(ApiConfig.getUserProfileEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      print('AuthService: getUserProfileById() calling URL: $url');

      final response = await http.get(url);
      print('AuthService: getUserProfileById() response status: ${response.statusCode}');
      print('AuthService: getUserProfileById() response body: ${response.body}');

      final decodedResponse = json.decode(response.body);

      if (decodedResponse['success'] && decodedResponse['user'] != null) {
        final userData = decodedResponse['user'];
        print('AuthService: getUserProfileById() user data types:');
        print('  - USER: ${userData['full_name']} (ID: ${userData['id']})');
        print('  - verification_status: ${userData['verification_status']} (${userData['verification_status'].runtimeType})');
        print('  - badge_status: ${userData['badge_status']} (${userData['badge_status'].runtimeType})');
      }

      return decodedResponse;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Upload profile picture ---
  Future<Map<String, dynamic>> uploadProfilePicture(String userId, XFile imageFile) async {
    try {
      print('🔧 Starting profile picture upload for user: $userId');
      print('🔧 Image file path: ${imageFile.path}');
      print('🔧 Image file name: ${imageFile.name}');
      
      // Get file info for debugging
      final file = File(imageFile.path);
      if (await file.exists()) {
        final fileSize = await file.length();
        print('🔧 File size: $fileSize bytes');
        
        // Try to determine MIME type
        final extension = imageFile.name.split('.').last.toLowerCase();
        String? mimeType;
        switch (extension) {
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
        }
        print('🔧 Detected MIME type: $mimeType');
      }
      
      var request = http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadProfilePictureEndpoint));
      request.fields['user_id'] = userId;
      
      print('🔧 Upload endpoint: ${ApiConfig.uploadProfilePictureEndpoint}');
      
      // Create MultipartFile with explicit MIME type
      final extension = imageFile.name.split('.').last.toLowerCase();
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'application/octet-stream';
      }
      
      print('🔧 Using explicit MIME type: $mimeType');
      
      request.files.add(await http.MultipartFile.fromPath(
        'profile_picture', 
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ));
      
      print('🔧 Sending multipart request...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print('🔧 Response status: ${response.statusCode}');
      print('🔧 Response body: ${response.body}');
      
      final responseData = jsonDecode(response.body);
      print('🔧 Parsed response: $responseData');
      
      return responseData;
    } catch (e) {
      print('🔧 Error uploading profile picture: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Update role ---
  Future<Map<String, dynamic>> updateRole({
    required String userId,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.updateRoleEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'role': role,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Update availability status ---
  Future<Map<String, dynamic>> updateAvailabilityStatus({
    required int userId,
    required bool isAvailable,
  }) async {
    try {
      print('AuthService: Updating availability status for user $userId to $isAvailable');
      print('AuthService: Using endpoint: ${ApiConfig.toggleStatusEndpoint}');
      
      final requestBody = {
        'user_id': userId,
        'is_available': isAvailable,
      };
      
      print('AuthService: Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse(ApiConfig.toggleStatusEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      
      print('AuthService: Response status: ${response.statusCode}');
      print('AuthService: Response body: ${response.body}');
      
      // Check if response is HTML instead of JSON
      if (response.body.trim().startsWith('<!DOCTYPE html>') || response.body.trim().startsWith('<html>')) {
        print('AuthService: ERROR - Received HTML instead of JSON. This usually means the API endpoint is incorrect or the server is returning an error page.');
        return {
          'success': false, 
          'message': 'API endpoint error: Received HTML response. Please check the server configuration.',
          'error_type': 'html_response'
        };
      }
      
      final responseData = json.decode(response.body);
      print('AuthService: Parsed response: $responseData');
      
      return responseData;
    } catch (e) {
      print('AuthService: Error updating availability status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Block user ---
  Future<Map<String, dynamic>> blockUser({
    required int userId,
    required int blockedUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.blockUserEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'blocked_user_id': blockedUserId,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Change password ---
  Future<Map<String, dynamic>> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    String? oldPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.changePasswordEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Fetch and set user if needed ---
  static Future<void> fetchAndSetUserIfNeeded() async {
    if (_currentUser == null) {
      await fetchAndSetUser();
    }
  }

  // --- Refresh user data ---
  static Future<bool> refreshUserData() async {
    try {
      await fetchAndSetUser();
      return _currentUser != null;
    } catch (e) {
      print('AuthService: Error refreshing user data: $e');
      return false;
    }
  }

  // --- Complete Social Registration ---
  static Future<Map<String, dynamic>> completeSocialRegistration({
    required Map<String, dynamic> socialUserData,
    required String firstName,
    required String middleName,
    required String lastName,
    required String birthday,
    required String addressDetails,
    required String gender,
    required String contactNumber,
    required String role,
    required double? latitude,
    required double? longitude,
    String? profileImageBase64,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.completeSocialRegistrationEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'social_user_data': socialUserData,
          'first_name': firstName,
          'middle_name': middleName,
          'last_name': lastName,
          'birthday': birthday,
          'address_details': addressDetails,
          'gender': gender,
          'contact_number': contactNumber,
          'role': role,
          'latitude': latitude,
          'longitude': longitude,
          'profile_image_base64': profileImageBase64,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (responseBody['success'] && responseBody['user'] != null) {
        // Save the completed user data
        final user = User.fromJson(responseBody['user']);
        await saveUser(user);

        // Save session if token is provided
        if (responseBody['token'] != null) {
          await saveUserSession(responseBody['token'], user.id!, user.role);
        }

        print('AuthService: Social registration completed successfully. User ID: ${user.id}');
      }

      return responseBody;
    } catch (e) {
      print('AuthService: Error completing social registration: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // --- Helper method to check if user profile is complete ---
  static bool _isUserProfileComplete(User user) {
    // Check if essential fields are filled
    bool hasBasicInfo = user.fullName.isNotEmpty &&
                       user.email.isNotEmpty;

    // Check location info (avoid default coordinates that indicate incomplete setup)
    bool hasLocationInfo = user.latitude != null &&
                          user.longitude != null &&
                          !(user.latitude == 37.4219983 && user.longitude == -122.084); // Default coordinates

    // Check role (if user has lister or doer role, they're complete)
    bool hasRole = user.role.isNotEmpty &&
                  (user.role == 'lister' || user.role == 'doer') &&
                  user.role != 'user';

    // Check personal information (required for complete profile)
    // For users with existing roles, be more lenient - they might have completed profile before gender was required
    bool hasPersonalInfo = user.contactNumber != null &&
                          user.contactNumber!.isNotEmpty &&
                          user.addressDetails != null &&
                          user.addressDetails!.isNotEmpty;

    // Only require gender for users without a valid role (new users going through completion)
    bool hasGender = user.gender != null && user.gender!.isNotEmpty;
    if (!hasRole && !hasGender) {
        hasPersonalInfo = false; // New users must have gender
    }

    // For social login users:
    // If user has a valid role (lister/doer) AND essential info, consider them complete
    // This handles users who completed registration before all fields were required
    bool isComplete;

    if (hasRole) {
        // User has a valid role - check if they have essential info (contact + address + location)
        bool hasEssentialInfo = user.contactNumber != null &&
                               user.contactNumber!.isNotEmpty &&
                               user.addressDetails != null &&
                               user.addressDetails!.isNotEmpty &&
                               hasLocationInfo;
        isComplete = hasBasicInfo && hasEssentialInfo;
        print('    * User has role - checking essential info only: $hasEssentialInfo');
    } else {
        // User has no role - require full profile completion including gender
        isComplete = hasBasicInfo && hasPersonalInfo && hasLocationInfo;
        print('    * User has no role - requiring full profile completion');
    }

    print('AuthService: Profile completeness check for ${user.email}:');
    print('  - Basic info: $hasBasicInfo');
    print('    * Full name: "${user.fullName}" (empty: ${user.fullName.isEmpty})');
    print('    * Email: "${user.email}" (empty: ${user.email.isEmpty})');
    print('  - Personal info: $hasPersonalInfo');
    print('    * Contact: "${user.contactNumber}" (null: ${user.contactNumber == null}, empty: ${user.contactNumber?.isEmpty})');
    print('    * Address: "${user.addressDetails}" (null: ${user.addressDetails == null}, empty: ${user.addressDetails?.isEmpty})');
    print('    * Gender: "${user.gender}" (null: ${user.gender == null}, empty: ${user.gender?.isEmpty})');
    print('    * Gender required: ${!hasRole} (users with roles can skip gender)');
    print('  - Location info: $hasLocationInfo');
    print('    * Latitude: ${user.latitude}, Longitude: ${user.longitude}');
    print('    * Is default coords: ${user.latitude == 37.4219983 && user.longitude == -122.084}');
    print('  - Role: $hasRole (role: "${user.role}")');
    print('  - Profile complete: $isComplete');
    print('  - Has role for dashboard: $hasRole');

    return isComplete;
  }

  // --- Login history ---
  static Future<List<LoginHistoryItem>> fetchLoginHistory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getLoginHistoryEndpoint).replace(queryParameters: {'user_id': userId.toString()}),
      );
      final data = json.decode(response.body);
      if (data['success'] && data['history'] != null) {
        final historyList = data['history'] as List;
        return historyList
            .map((item) => LoginHistoryItem.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      print('AuthService: Error fetching login history: $e');
      return [];
    }
  }

  static Future<bool> logLoginHistory(int userId) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final response = await http.post(
        Uri.parse(ApiConfig.logLoginHistoryEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'device_info': deviceInfo,
        }),
      );
      final data = json.decode(response.body);
      return data['success'] ?? false;
    } catch (e) {
      print('AuthService: Error logging login history: $e');
      return false;
    }
  }

  // --- Device info ---
  static Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  // --- Preserved availability methods ---
  static Future<bool?> getPreservedAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('preserved_availability');
  }

  static Future<void> clearPreservedAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('preserved_availability');
  }

  // --- User Status Verification ---
  static Future<Map<String, dynamic>> checkUserStatus({
    required int userId,
    String? deviceInfo,
    String action = 'check', // 'check' or 'login'
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.checkUserStatusEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'device_info': deviceInfo ?? await _getDeviceInfo(),
          'action': action,
        }),
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      
      if (responseBody['success'] && responseBody['user'] != null) {
        // Update local user data with fresh data from server
        final user = User.fromJson(responseBody['user']);
        await saveUser(user);
      }
      
      return responseBody;
    } catch (e) {
      print('AuthService: Error checking user status: $e');
      return {
        'success': false, 
        'message': 'Network error: $e',
        'error_type': 'network_error'
      };
    }
  }

  // --- Facebook Key Hash Helper (for development) ---
  static Future<void> printFacebookKeyHash() async {
    if (Platform.isAndroid) {
      try {
        // This will help developers get the key hash for Facebook setup
        print('=== FACEBOOK KEY HASH FOR DEVELOPMENT ===');
        print('Package Name: com.example.hanapp');
        print('Class Name: com.example.hanapp.MainActivity');
        print('');
        print('To get your key hash, run this command in terminal:');
        print('keytool -exportcert -alias test -keystore android/app/login.jks -storepass loginhanapp -keypass loginhanapp | openssl sha1 -binary | openssl base64');
        print('');
        print('Or use the Facebook SDK method in MainActivity.java');
        print('==========================================');
      } catch (e) {
        print('Error getting Facebook key hash info: $e');
      }
    }
  }

  // --- Helper methods ---
  static Future<void> _saveUserToPrefs(User user, dynamic token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
    await prefs.setString(_tokenKey, token.toString());
    _currentUser = user;
  }

  static Future<void> _removeUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    _currentUser = null;
  }

  // Helper method to update existing user with social login information
  static Future<Map<String, dynamic>> _updateExistingUserWithSocialInfo({
    required String email,
    required String provider,
    required String firebaseUid,
    required String fullName,
    String? profilePictureUrl,
    String? deviceInfo,
  }) async {
    try {
      print('Attempting to update existing user with social info...');

      // For now, let's try a simple approach - just attempt social login
      // since the user exists, maybe they already have social info
      final loginResponse = await _attemptSocialLogin(email, firebaseUid, deviceInfo);

      if (loginResponse['success']) {
        print('Social login successful after retry');
        return loginResponse;
      }

      // If that fails, return a message asking user to login with email/password first
      return {
        'success': false,
        'message': 'This email is already registered. Please login with your email and password first, then link your Facebook account in settings.'
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating user with social info: $e'
      };
    }
  }

  // Helper method to get current location with better error handling
  static Future<Map<String, double?>> _getCurrentLocation() async {
    try {
      print('Checking location services...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled, using default coordinates');
        return {'latitude': 0.0, 'longitude': 0.0};
      }

      print('Checking location permissions...');

      // Check location permissions with timeout
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Requesting location permission...');

        // Add timeout for permission request
        permission = await Geolocator.requestPermission().timeout(
          Duration(seconds: 15),
          onTimeout: () {
            print('Location permission request timed out');
            return LocationPermission.denied;
          },
        );

        if (permission == LocationPermission.denied) {
          print('Location permissions denied, using default coordinates');
          return {'latitude': 0.0, 'longitude': 0.0};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied, using default coordinates');
        return {'latitude': 0.0, 'longitude': 0.0};
      }

      print('Getting current position...');

      // Get current position with shorter timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Changed from high to medium
        timeLimit: Duration(seconds: 8), // Reduced timeout
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Location request timed out');
          throw Exception('Location request timed out');
        },
      );

      print('Location obtained successfully: ${position.latitude}, ${position.longitude}');

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('Error getting location: $e');
      // Return default coordinates if location fails
      return {
        'latitude': 0.0,
        'longitude': 0.0,
      };
    }
  }
}