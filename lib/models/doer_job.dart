import 'package:hanapp/models/user.dart'; // For Lister details (if needed elsewhere in the app)
import 'package:intl/intl.dart'; // Keep for getTimeAgo() and general date formatting

class DoerJob {
  final int id; //13/06/2025
  final int doerId;//13/06/2025

  final int applicationId;
  final int listingId;
  final String listingType; // 'PUBLIC' or 'ASAP'
  final String message; // Application message
  final String applicationStatus; // 'pending', 'accepted', 'rejected', 'completed', 'cancelled', 'in_progress'
  final DateTime appliedAt;

  // Listing details
  final String title;
  final String? description;
  final double price;
  final String locationAddress; // Renamed from 'location' to be more specific
  final String? category;
  final DateTime? listingCreatedAt; // Original posting date of the listing

  // Lister details
  final int listerId;
  final String? listerFullName;
  final String? listerProfilePictureUrl;

  // Additional fields for completed/cancelled jobs
  final double? earnedAmount;
  final String? transactionNo;
  final String? cancellationReason;

  // Additional fields for the card layout
  final int views;
  final int applicantsCount;
  final bool isASAP;
  final int? conversationId; // Made nullable as it might not always exist for all jobs

  DoerJob({
    required this.id,
    required this.doerId,

    required this.applicationId,
    required this.listingId,
    required this.listingType,
    required this.message,
    required this.applicationStatus,
    required this.appliedAt,
    required this.title,
    this.description,
    required this.price,
    required this.locationAddress,
    this.category,
    this.listingCreatedAt,
    required this.listerId,
    this.listerFullName,
    this.listerProfilePictureUrl,
    this.earnedAmount,
    this.transactionNo,
    this.cancellationReason,
    required this.views,
    required this.applicantsCount,
    this.isASAP = false,
    this.conversationId, // Now nullable
  });

  factory DoerJob.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime? parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return null;
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('DoerJob: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        // Log or handle parsing error, e.g., for malformed dates
        print('DoerJob: Error parsing date "$value": $e');
        return null;
      }
    }
    
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
        print('DoerJob: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('DoerJob: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }
    
    return DoerJob(
      id: safeInt(json['id']), // Assuming 'id' from backend is application_id
      doerId: safeInt(json['doer_id']),

      applicationId: int.tryParse(json['application_id'].toString()) ?? 0,
      listingId: int.tryParse(json['listing_id'].toString()) ?? 0,
      listingType: json['listing_type'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '',
      applicationStatus: json['application_status'] as String? ?? 'unknown',
      appliedAt: parseDateTime(json['applied_at']) ?? DateTime.now(), // Fallback to now if null/invalid
      title: json['title'] as String? ?? 'No Title',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      locationAddress: json['location_address'] as String? ?? 'N/A',
      category: json['category'] as String?,
      listingCreatedAt: parseDateTime(json['listing_created_at']), // Can be null
      listerId: int.tryParse(json['lister_id'].toString()) ?? 0, // Ensure int and fallback
      listerFullName: json['lister_full_name'] as String?,
      listerProfilePictureUrl: json['lister_profile_picture_url'] as String?,
      earnedAmount: json['earned_amount'] != null ? (json['earned_amount'] as num).toDouble() : null,
      transactionNo: json['transaction_no'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,

      views: int.tryParse(json['views'].toString()) ?? 0, // Safe parse with fallback
      applicantsCount: int.tryParse(json['applicants_count'].toString()) ?? 0, // Safe parse with fallback
      isASAP: json['is_asap'] == 1 || (json['is_asap'] is bool && json['is_asap'] == true), // Consistent boolean check
      conversationId: int.tryParse(json['conversation_id'].toString()), // Now nullable, so can be null
    );
  }

  // Helper method to calculate time ago from listingCreatedAt (was postedAt previously)
  String getTimeAgo() {
    if (listingCreatedAt == null) {
      return 'N/A';
    }
    final Duration diff = DateTime.now().difference(listingCreatedAt!);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
