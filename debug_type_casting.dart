// Debug script to test type casting fixes
// Run this in your Flutter project to test the fixes

import 'dart:convert';

void main() {
  print('=== Testing Type Casting Fixes ===\n');
  
  // Test 1: Simulate backend response with mixed types (the problem scenario)
  print('Test 1: Mixed types from backend (problematic scenario)');
  Map<String, dynamic> problematicResponse = {
    'id': 87,
    'full_name': 'Test User',
    'email': 'test@example.com',
    'role': 'lister',
    'verification_status': 0, // This was causing the error - integer instead of string
    'badge_status': 1, // This was also problematic
    'id_verified': 0,
    'badge_acquired': 0,
    'profile_picture_url': null,
  };
  
  try {
    String verificationStatus = _safeStringValue(problematicResponse['verification_status'], 'unverified');
    String badgeStatus = _safeStringValue(problematicResponse['badge_status'], 'none');
    print('✅ verification_status: "$verificationStatus" (${verificationStatus.runtimeType})');
    print('✅ badge_status: "$badgeStatus" (${badgeStatus.runtimeType})');
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\nTest 2: Proper string types from backend (expected scenario)');
  Map<String, dynamic> properResponse = {
    'id': 87,
    'full_name': 'Test User',
    'email': 'test@example.com',
    'role': 'lister',
    'verification_status': 'unverified', // Proper string
    'badge_status': 'none', // Proper string
    'id_verified': false,
    'badge_acquired': false,
    'profile_picture_url': null,
  };
  
  try {
    String verificationStatus = _safeStringValue(properResponse['verification_status'], 'unverified');
    String badgeStatus = _safeStringValue(properResponse['badge_status'], 'none');
    print('✅ verification_status: "$verificationStatus" (${verificationStatus.runtimeType})');
    print('✅ badge_status: "$badgeStatus" (${badgeStatus.runtimeType})');
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\nTest 3: Null values (edge case)');
  Map<String, dynamic> nullResponse = {
    'id': 87,
    'full_name': 'Test User',
    'email': 'test@example.com',
    'role': 'lister',
    'verification_status': null,
    'badge_status': null,
    'id_verified': null,
    'badge_acquired': null,
    'profile_picture_url': null,
  };
  
  try {
    String verificationStatus = _safeStringValue(nullResponse['verification_status'], 'unverified');
    String badgeStatus = _safeStringValue(nullResponse['badge_status'], 'none');
    print('✅ verification_status: "$verificationStatus" (${verificationStatus.runtimeType})');
    print('✅ badge_status: "$badgeStatus" (${badgeStatus.runtimeType})');
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\nTest 4: Boolean values (another edge case)');
  Map<String, dynamic> boolResponse = {
    'id': 87,
    'full_name': 'Test User',
    'email': 'test@example.com',
    'role': 'lister',
    'verification_status': true,
    'badge_status': false,
    'id_verified': true,
    'badge_acquired': false,
    'profile_picture_url': null,
  };
  
  try {
    String verificationStatus = _safeStringValue(boolResponse['verification_status'], 'unverified');
    String badgeStatus = _safeStringValue(boolResponse['badge_status'], 'none');
    print('✅ verification_status: "$verificationStatus" (${verificationStatus.runtimeType})');
    print('✅ badge_status: "$badgeStatus" (${badgeStatus.runtimeType})');
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n=== All Tests Completed ===');
}

// Helper method to safely convert any value to string (same as in VerificationScreen)
String _safeStringValue(dynamic value, String defaultValue) {
  if (value == null) return defaultValue;
  if (value is String) return value.isEmpty ? defaultValue : value;
  if (value is int || value is double || value is bool) return value.toString();
  return value.toString();
}
