import 'package:hanapp/models/user.dart';

class Review {
  final int id;
  final int reviewerId;
  final String reviewerFullName;
  final String? reviewerProfilePictureUrl;
  final int reviewedUserId;
  final int? listingId;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final User? reviewer; // Details of the user who wrote the review
  final List<String> reviewImages; // List of image URLs for the review
  final int applicationId;
  final int listerId;
  final int doerId;
  final String reviewContent;
  final String listerFullName; // From joined user data
  final String? listerProfilePictureUrl; // From joined user data
  final String listingType; // e.g., 'PUBLIC', 'ASAP'
  final String reviewMessage; // The main review content from the Lister
  final DateTime reviewedAt;
  final String? doerReplyMessage; // The Doer's reply to the review (can be null)
  final DateTime? repliedAt;      // When the Doer replied (can be null)


  Review({
    required this.id,
    required this.reviewerId,
    required this.reviewerFullName,
    this.reviewerProfilePictureUrl,
    required this.reviewedUserId,
    this.listingId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reviewer,
    this.reviewImages = const [],

    required this.applicationId,
    required this.listerId,
    required this.doerId,
    required this.reviewContent,
    required this.listerFullName,
    this.listerProfilePictureUrl,

    // required this.id,
    // required this.listingId,
    required this.listingType,
    // required this.listerId,
    // required this.listerFullName,
    // this.listerProfilePictureUrl,
    // required this.doerId,
    // required this.rating,
    required this.reviewMessage,
    required this.reviewedAt,
    this.doerReplyMessage,
    this.repliedAt,
    // this.applicationId,
  });

  factory Review.fromJson(Map<String, dynamic> json) {

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
        print('Review: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('Review: Error parsing date "$value": $e. Using DateTime.now().');
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
        print('Review: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('Review: Error parsing nullable date "$value": $e. Using null.');
        return null;
      }
    }
    return Review(
      id: int.parse(json['id'].toString()),
      reviewerId: int.parse(json['reviewer_id'].toString()),
      reviewerFullName: json['reviewer_name'] as String,
      reviewerProfilePictureUrl: json['reviewer_profile_picture_url'] as String?,
      reviewedUserId: int.parse(json['reviewed_user_id'].toString()),
      listingId: json['listing_id'] != null ? int.parse(json['listing_id'].toString()) : null,
      rating: double.parse(json['rating'].toString()),
      comment: json['comment'] as String,
      // createdAt: DateTime.parse(json['created_at'] as String),

      applicationId: int.tryParse(json['application_id'].toString()) ?? 0,
      listerId: int.tryParse(json['lister_id'].toString()) ?? 0,
      doerId: int.tryParse(json['doer_id'].toString()) ?? 0,
      reviewContent: json['review_content'] as String,
      createdAt: json['created_at'] != null
          ? (() {
              try {
                final utcDateTime = DateTime.parse(json['created_at'].toString() + 'Z');
                return utcDateTime.toLocal();
              } catch (e) {
                print('Review: Error parsing created_at: $e. Using DateTime.now().');
                return DateTime.now();
              }
            })()
          : DateTime.now(), // Fallback
      listerFullName: json['lister_full_name'] as String, // From join
      listerProfilePictureUrl: json['lister_profile_picture_url'] as String?,

      reviewer: json['reviewer_id'] != null // Construct reviewer if data is available
          ? User(
        id: int.parse(json['reviewer_id'].toString()),
        fullName: json['reviewer_full_name'] as String,
        email: '', // Email might not be needed for public display
        role: '', // Role might not be needed for public display
        profilePictureUrl: json['reviewer_profile_picture_url'] as String?,
        addressDetails: json['reviewer_address_details'] as String?,
      )
          : null,
      reviewImages: (json['review_images'] as List?)?.map((e) => e.toString()).toList() ?? [],

      // id: safeInt(json['id']),
      // listingId: safeInt(json['listing_id']),
      listingType: safeString(json['listing_type'], defaultValue: 'PUBLIC'), // Defaulting if not provided
      // listerId: safeInt(json['lister_id']),
      // listerFullName: safeString(json['lister_full_name']),
      // listerProfilePictureUrl: safeNullableString(json['lister_profile_picture_url']),
      // doerId: safeInt(json['doer_id']),
      // rating: safeDouble(json['rating']),
      reviewMessage: safeString(json['review_message']),
      reviewedAt: safeDateTime(json['reviewed_at']),
      doerReplyMessage: safeNullableString(json['doer_reply_message']),
      repliedAt: safeNullableDateTime(json['replied_at']),
      // applicationId: safeNullableInt(json['application_id']), // Assuming this might be passed
    );
  }

  String? get reviewerName => null;

  static int? safeNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewer_id': reviewerId,
      'reviewer_name': reviewerFullName,
      'reviewer_profile_picture_url': reviewerProfilePictureUrl,
      'reviewed_user_id': reviewedUserId,
      'listing_id': listingId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'reviewer': reviewer?.toJson(), // Convert reviewer to JSON if present
      'review_images': reviewImages,
    };
  }

  Review copyWith({
    int? id,
    int? reviewerId,
    String? reviewerFullName,
    String? reviewerProfilePictureUrl,
    int? reviewedUserId,
    int? listingId,
    double? rating,
    String? comment,
    DateTime? createdAt,
    User? reviewer,
    List<String>? reviewImages,
    int? applicationId,
    int? listerId,
    int? doerId,
    String? reviewContent,
    String? listerFullName,
    String? listerProfilePictureUrl,
    String? listingType,
    String? reviewMessage,
    DateTime? reviewedAt,
    String? doerReplyMessage,
    DateTime? repliedAt,
  }) {
    return Review(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerFullName: reviewerFullName ?? this.reviewerFullName,
      reviewerProfilePictureUrl: reviewerProfilePictureUrl ?? this.reviewerProfilePictureUrl,
      reviewedUserId: reviewedUserId ?? this.reviewedUserId,
      listingId: listingId ?? this.listingId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      reviewer: reviewer ?? this.reviewer,
      reviewImages: reviewImages ?? this.reviewImages,
      applicationId: applicationId ?? this.applicationId,
      listerId: listerId ?? this.listerId,
      doerId: doerId ?? this.doerId,
      reviewContent: reviewContent ?? this.reviewContent,
      listerFullName: listerFullName ?? this.listerFullName,
      listerProfilePictureUrl: listerProfilePictureUrl ?? this.listerProfilePictureUrl,
      listingType: listingType ?? this.listingType,
      reviewMessage: reviewMessage ?? this.reviewMessage,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      doerReplyMessage: doerReplyMessage ?? this.doerReplyMessage,
      repliedAt: repliedAt ?? this.repliedAt,
    );
  }

  List<String> get reviewImageUrls => reviewImages;
}
