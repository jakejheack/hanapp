import 'package:hanapp/models/review.dart';

class User {
  final int id;
  final String fullName; // Combined from first, middle, last names
  final String email;
  final String role; // 'lister' or 'doer'
  // final bool? isVerified;
  String? profilePictureUrl;
  final double? averageRating; // Make nullable
  final int? reviewCount; // Make nullable
  // final String? addressDetails; // Changed to non-final
  final String? addressDetails; // Consolidated address string
  final double? latitude; // NEW: User's latitude
  final double? longitude; // NEW: User's longitude
  // String? contactNumber; // NEW: Added contactNumber
  final int totalReviews; // NEW: Total number of reviews
  final List<Review>? reviews; // NEW: List of reviews for this user
  // NEW fields
  final DateTime? birthday;
  final String? gender;
  final String? contactNumber;
  final bool isVerified; // NEW: Email verification status
  final bool? isAvailable;
  final double? totalProfit; // NEW: Added for Doer's total profit
  final DateTime? createdAt; // NEW: Added for user creation date (Started on)

  // NEW: Verification-related fields
  final bool isIdVerified; // Maps to id_verified
  final bool isBadgeAcquired; // Maps to badge_acquired
  final String verificationStatus; // Maps to verification_status
  final String badgeStatus; // Maps to badge_status
  final String? idPhotoFrontUrl;
  final String? idPhotoBackUrl;
  final String? brgyClearancePhotoUrl; // NEW FIELD
  final String? livePhotoUrl;

  // NEW: Account status fields
  final DateTime? bannedUntil; // Maps to banned_until
  final bool isDeleted; // Maps to is_deleted (0 = false, 1 = true)

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.profilePictureUrl,
    this.averageRating = 0.0,
    this.reviewCount,
    this.addressDetails,
    this.latitude,
    this.longitude,
    this.contactNumber, // NEW
    this.totalReviews = 0,    // Default value
    this.reviews, // Initialize reviews

    this.birthday,
    this.gender,
    this.isVerified = false, // Initialize to false by default
    this.isAvailable,
    this.totalProfit, // Initialize in construct
    this.createdAt, // Initialize in constructor

    // NEW fields in constructor
    this.isIdVerified = false,
    this.isBadgeAcquired = false,
    this.verificationStatus = 'unverified',
    this.badgeStatus = 'none',
    this.idPhotoFrontUrl,
    this.idPhotoBackUrl,
    this.brgyClearancePhotoUrl, // NEW
    this.livePhotoUrl,

    // NEW: Account status fields
    this.bannedUntil,
    this.isDeleted = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Add comprehensive logging for debugging
    print('User.fromJson: Processing user data for: ${json['full_name']} (ID: ${json['id']})');
    print('User.fromJson: verification_status = ${json['verification_status']} (${json['verification_status'].runtimeType})');
    print('User.fromJson: badge_status = ${json['badge_status']} (${json['badge_status'].runtimeType})');

    List<Review>? userReviews;
    if (json['reviews'] != null) { // Assuming the backend sends a 'reviews' array
      userReviews = (json['reviews'] as List)
          .map((reviewJson) => Review.fromJson(reviewJson))
          .toList();
    }
    // Combine address parts for addressDetails
    // isAvailable: json['is_available'] == 1 || json['is_available'] == true,
    
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;

      String? stringValue;
      if (value is String) {
        if (value.isEmpty) return null;
        stringValue = value;
      } else if (value is int || value is double) {
        // Convert timestamp to string
        stringValue = value.toString();
      } else {
        print('User: parseDateTime unexpected type ${value.runtimeType} for value: $value');
        return null;
      }

      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(stringValue + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('User: Parsed UTC timestamp "$stringValue" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('User: Error parsing date "$stringValue": $e. Using null.');
        return null;
      }
    }

    DateTime? parsedCreatedAt = parseDateTime(json['created_at']);

    // Helper for boolean parsing from tinyint(1)
    bool safeBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'true';
      return false;
    }

    String safeString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      if (value is String) {
        if (value.isEmpty) return defaultValue; // Handle empty strings
        return value;
      }
      if (value is int || value is double || value is bool) {
        return value.toString();
      }
      // Add debug logging for unexpected types
      print('User.safeString: Unexpected type ${value.runtimeType} for value: $value');
      return value.toString();
    }

    String? safeNullableString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        if (value.isEmpty) return null; // Convert empty strings to null
        return value;
      }
      if (value is int || value is double || value is bool) {
        String stringValue = value.toString();
        return stringValue.isEmpty ? null : stringValue;
      }
      return value.toString();
    }
    try {
      return User(
        id: int.parse(json['id'].toString()),
        fullName: safeString(json['full_name'], defaultValue: 'Unknown User'),
        email: safeString(json['email'], defaultValue: ''),
        role: safeString(json['role'], defaultValue: 'doer'),
      // isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      profilePictureUrl: safeNullableString(json['profile_picture_url']),
      averageRating: json['average_rating'] != null ? double.parse(json['average_rating'].toString()) : 0.0,
      totalReviews: json['total_reviews'] != null ? int.parse(json['total_reviews'].toString()) : 0,
      reviewCount: json['review_count'] != null ? int.parse(json['review_count'].toString()) : null,
      addressDetails: safeNullableString(json['address_details']),
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null, // Parse latitude
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null, // Parse longitude
      // contactNumber: json['contact_number'], // NEW
      reviews: userReviews,
      birthday: parseDateTime(json['birthday']),
      gender: safeNullableString(json['gender']),
      contactNumber: safeNullableString(json['contact_number']),
      isVerified: safeBool(json['is_verified']),
      // isAvailable: json['is_available'] == 1 || json['is_available'] == true,
      isAvailable: safeBool(json['is_available']),
      totalProfit: json['total_profit'] != null ? (json['total_profit'] as num).toDouble() : 0.0,
      createdAt: parsedCreatedAt,


      // NEW fields from JSON
      isIdVerified: safeBool(json['id_verified']),
      isBadgeAcquired: safeBool(json['badge_acquired']),
      verificationStatus: (() {
        print('User.fromJson: verification_status raw value: ${json['verification_status']} (${json['verification_status'].runtimeType})');
        return safeString(json['verification_status'], defaultValue: 'unverified');
      })(),
      badgeStatus: (() {
        print('User.fromJson: badge_status raw value: ${json['badge_status']} (${json['badge_status'].runtimeType})');
        return safeString(json['badge_status'], defaultValue: 'none');
      })(),
      idPhotoFrontUrl: safeNullableString(json['id_photo_front_url']),
      idPhotoBackUrl: safeNullableString(json['id_photo_back_url']),
      brgyClearancePhotoUrl: safeNullableString(json['brgy_clearance_photo_url']), // NEW
      livePhotoUrl: safeNullableString(json['live_photo_url']),

        // NEW: Account status fields
        bannedUntil: parseDateTime(json['banned_until']),
        isDeleted: safeBool(json['is_deleted']),
      );
    } catch (e, stackTrace) {
      print('User.fromJson: Error creating User object: $e');
      print('User.fromJson: Stack trace: $stackTrace');
      print('User.fromJson: Raw JSON data: $json');

      // Try to identify which field is causing the issue
      print('User.fromJson: Testing individual fields...');
      try { print('  - id: ${json['id']} (${json['id'].runtimeType})'); } catch (e) { print('  - id: ERROR - $e'); }
      try { print('  - full_name: ${json['full_name']} (${json['full_name'].runtimeType})'); } catch (e) { print('  - full_name: ERROR - $e'); }
      try { print('  - email: ${json['email']} (${json['email'].runtimeType})'); } catch (e) { print('  - email: ERROR - $e'); }
      try { print('  - role: ${json['role']} (${json['role'].runtimeType})'); } catch (e) { print('  - role: ERROR - $e'); }
      try { print('  - verification_status: ${json['verification_status']} (${json['verification_status'].runtimeType})'); } catch (e) { print('  - verification_status: ERROR - $e'); }
      try { print('  - badge_status: ${json['badge_status']} (${json['badge_status'].runtimeType})'); } catch (e) { print('  - badge_status: ERROR - $e'); }

      rethrow; // Re-throw the error so it can be handled by the calling code
    }
  }

  get address => null;
  User copyWith({
    int? id,
    String? fullName,
    String? email,
    String? role,
    String? profilePictureUrl,
    String? addressDetails,
    bool? isAvailable,
    double? totalProfit,
    bool? isVerified,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    String? contactNumber,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      addressDetails: addressDetails ?? this.addressDetails,
      isAvailable: isAvailable ?? this.isAvailable,
      totalProfit: totalProfit ?? this.totalProfit,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactNumber: contactNumber ?? this.contactNumber,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      // 'is_verified': isVerified,
      'profile_picture_url': profilePictureUrl,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'address_details': addressDetails,
      'latitude': latitude,
      'longitude': longitude,
      'contact_number': contactNumber, // NEW
      'total_reviews': totalReviews,
      'reviews': reviews?.map((e) => e.toJson()).toList(),

      'birthday': birthday?.toIso8601String(),
      'is_verified': isVerified ? 1 : 0, // Serialize is_verified
      // 'is_available': user.isAvailable, // Include isAvailable
      'is_available': isAvailable,
      'total_profit': totalProfit,
      'created_at': createdAt?.toIso8601String(),

      // NEW fields for JSON conversion
      'id_verified': isIdVerified ? 1 : 0,
      'badge_acquired': isBadgeAcquired ? 1 : 0,
      'verification_status': verificationStatus,
      'badge_status': badgeStatus,
      'id_photo_front_url': idPhotoFrontUrl,
      'id_photo_back_url': idPhotoBackUrl,
      'brgy_clearance_photo_url': brgyClearancePhotoUrl, // NEW
      'live_photo_url': livePhotoUrl,

      // NEW: Account status fields
      'banned_until': bannedUntil?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}