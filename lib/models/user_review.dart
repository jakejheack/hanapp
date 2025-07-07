import 'package:hanapp/models/user.dart'; // Assuming User model for general user details.

class Review {
  final int id; // ID of the review record itself
  final int listingId; // The listing ID this review is associated with
  final String listingType; // e.g., 'PUBLIC', 'ASAP'

  // Details of the Lister (reviewer) who wrote this review
  final int listerId;
  final String listerFullName;
  final String? listerProfilePictureUrl;

  // Details of the Doer (reviewed user) who received this review
  final int doerId;

  // The main review content from the Lister
  final double rating;
  final String reviewContent; // This is the actual review comment/content
  final DateTime createdAt; // When the Lister posted the review

  // The Doer's reply to this review (nullable)
  final String? doerReplyMessage; // Doer's reply (can be null if not yet replied)
  final DateTime? repliedAt;      // When the Doer replied (can be null)

  final int? applicationId; // Optional: Link to the specific application this review is for
  final List<String> reviewImageUrls; // NEW: List of image URLs for the review
  final String? projectTitle; // NEW: Title of the project being reviewed

  Review({
    required this.id,
    required this.listingId,
    required this.listingType,
    required this.listerId,
    required this.listerFullName,
    this.listerProfilePictureUrl,
    required this.doerId,
    required this.rating,
    required this.reviewContent,
    required this.createdAt,
    this.doerReplyMessage,
    this.repliedAt,
    this.applicationId,
    this.reviewImageUrls = const [], // Initialize as empty list
    this.projectTitle,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int, default to 0
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Helper to safely parse double, default to 0.0
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to safely parse String, default to empty string
    String safeString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely parse nullable String
    String? safeNullableString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    // Helper to safely parse DateTime, providing a non-null fallback
    DateTime safeDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('UserReview: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('UserReview: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    // Helper to safely parse nullable DateTime
    DateTime? safeNullableDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return null;
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('UserReview: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('UserReview: Error parsing nullable date "$value": $e. Using null.');
        return null;
      }
    }

    // Helper for safe nullable int parsing
    int? safeNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // NEW: Helper to safely parse list of image URLs from a comma-separated string
    List<String> safeImageUrls(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return [];
      }
      return value.split(',').map((url) => url.trim()).where((url) => url.isNotEmpty).toList();
    }

    return Review(
      id: safeInt(json['id']),
      listingId: safeInt(json['listing_id']),
      listingType: safeString(json['listing_type'], defaultValue: 'PUBLIC'),
      listerId: safeInt(json['lister_id']),
      listerFullName: safeString(json['lister_full_name']),
      listerProfilePictureUrl: safeNullableString(json['lister_profile_picture_url']),
      doerId: safeInt(json['doer_id']),
      rating: safeDouble(json['rating']),
      reviewContent: safeString(json['review_content']), // Use review_message for the content
      createdAt: safeDateTime(json['created_at']),     // Use reviewed_at for the date
      doerReplyMessage: safeNullableString(json['doer_reply_message']),
      repliedAt: safeNullableDateTime(json['replied_at']),
      applicationId: safeNullableInt(json['application_id']),
      reviewImageUrls: safeImageUrls(json['review_image_urls']), // NEW: Parse image URLs
      projectTitle: safeNullableString(json['project_title']), // NEW: Parse project title
    );
  }

  // Method to create a copy of the Review object with updated fields
  Review copyWith({
    int? id,
    int? listingId,
    String? listingType,
    int? listerId,
    String? listerFullName,
    String? listerProfilePictureUrl,
    int? doerId,
    double? rating,
    String? reviewContent,
    DateTime? createdAt,
    String? doerReplyMessage,
    DateTime? repliedAt,
    int? applicationId,
    List<String>? reviewImageUrls, // NEW: Include in copyWith
    String? projectTitle, // NEW: Include in copyWith
  }) {
    return Review(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingType: listingType ?? this.listingType,
      listerId: listerId ?? this.listerId,
      listerFullName: listerFullName ?? this.listerFullName,
      listerProfilePictureUrl: listerProfilePictureUrl ?? this.listerProfilePictureUrl,
      doerId: doerId ?? this.doerId,
      rating: rating ?? this.rating,
      reviewContent: reviewContent ?? this.reviewContent,
      createdAt: createdAt ?? this.createdAt,
      doerReplyMessage: doerReplyMessage ?? this.doerReplyMessage,
      repliedAt: repliedAt ?? this.repliedAt,
      applicationId: applicationId ?? this.applicationId,
      reviewImageUrls: reviewImageUrls ?? this.reviewImageUrls, // NEW: Assign
      projectTitle: projectTitle ?? this.projectTitle, // NEW: Assign
    );
  }
}
