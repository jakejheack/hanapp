import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/utils/google_signin_config.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
    ],
  );

  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  static Future<void> initialize() async {
    try {
      // Check if user is already signed in
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('User already signed in: ${currentUser.email}');
      }
      print('Google Sign-In initialized successfully');
    } catch (e) {
      print('Failed to initialize Google Sign-In: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Start the Google Sign-In process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In was cancelled by user');
        return null;
      }

      // Get authentication details from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Debug: Print tokens for testing
      print('=== Google Sign-In Tokens ===');
      print('Access Token: ${googleAuth.accessToken}');
      print('ID Token: ${googleAuth.idToken}');
      print('=== End Tokens ===');
      
      // Create Firebase credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final firebase_auth.UserCredential userCredential = await _auth.signInWithCredential(credential);
      final firebase_auth.User? user = userCredential.user;

      if (user == null) {
        print('Failed to get Firebase user');
        return null;
      }

      print('Successfully signed in with Firebase: ${user.email}');

      // Return Firebase user data
      final userData = <String, dynamic>{
        'id': user.uid,
        'email': user.email,
        'name': user.displayName,
        'photo_url': user.photoURL,
        'id_token': await user.getIdToken(),
        'access_token': googleAuth.accessToken,
        'is_verified': user.emailVerified,
        'is_available': true,
        'role': '', // Will be set later
      };

      return userData;

    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      print('Successfully signed out');
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  static firebase_auth.User? getCurrentUser() {
    return _auth.currentUser;
  }

  static bool isSignedIn() {
    return _auth.currentUser != null;
  }

  static Stream<firebase_auth.User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // Get user authentication
  static Future<GoogleSignInAuthentication?> getAuthentication() async {
    try {
      final currentUser = _googleSignIn.currentUser;
      if (currentUser != null) {
        return await currentUser.authentication;
      }
      return null;
    } catch (e) {
      print('Error getting authentication: $e');
      return null;
    }
  }

  // Get user info from Google People API
  static Future<Map<String, dynamic>?> getUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(GoogleSignInConfig.googleUserInfoUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  // Verify ID token with Google
  static Future<Map<String, dynamic>?> verifyIdToken(String idToken) async {
    try {
      final response = await http.get(
        Uri.parse('${GoogleSignInConfig.googleTokenInfoUrl}?id_token=$idToken'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to verify ID token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error verifying ID token: $e');
      return null;
    }
  }
} 