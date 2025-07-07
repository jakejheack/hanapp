import 'package:intl/intl.dart';

class CombinedListingItem {
  final int id;
  final int listerId;
  final String title;
  final String? description;
  final String category; // 'Onsite', 'Remote', 'Hybrid', 'ASAP' for public; 'ASAP' for ASAP
  final double? price; // Nullable for public listings, mandatory for ASAP
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final bool isActive;
  final String? tags;
  final String listingType; // 'PUBLIC' or 'ASAP'
  final int views; // Added views
  final int applicants; // Added applicants
  final String status;

  CombinedListingItem({
    required this.id,
    required this.listerId,
    required this.title,
    this.description,
    required this.category,
    this.price,
    this.locationAddress,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.isActive,
    this.tags,
    required this.listingType,
    this.views = 0, // Default to 0
    this.applicants = 0, // Default to 0
    required this.status, // <<<<<<<<<< NEW: Added to constructor
  });

  factory CombinedListingItem.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        // print('CombinedListingItem: Parsed UTC timestamp "$value" to local time: $localDateTime'); // Keep for debugging if needed
        return localDateTime;
      } catch (e) {
        print('CombinedListingItem: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    return CombinedListingItem(
      id: json['id'] as int,
      listerId: json['lister_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      locationAddress: json['location_address'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      createdAt: parseDateTime(json['created_at']),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      tags: json['tags'] as String?,
      listingType: json['listing_type'] as String,
      views: json['views'] as int? ?? 0, // Parse views, default to 0
      applicants: json['applicants'] as int? ?? 0, // Parse applicants, default to 0
      status: json['status'] as String? ?? 'ONGOING',
    );
  }

  // Helper method to get time ago display
  String getTimeAgo() { // Renamed from getLocationAndTimeDisplay to clarify purpose
    Duration difference = DateTime.now().difference(createdAt);

    String timeAgo;
    if (difference.inDays > 365) {
      timeAgo = '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      timeAgo = '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 7) {
      timeAgo = '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      timeAgo = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      timeAgo = '${difference.inMinutes}m ago';
    } else {
      timeAgo = 'Just now';
    }
    return timeAgo;
  }

  // Method to get location display (separated from time ago for flexibility)
  String getLocationDisplay() {
    return locationAddress != null && locationAddress!.isNotEmpty
        ? locationAddress!
        : 'Location not specified';
  }

  // Optional: Add a copyWith method for immutability and convenience
  CombinedListingItem copyWith({
    int? id,
    int? listerId,
    String? title,
    String? description,
    String? category,
    double? price,
    String? locationAddress,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    bool? isActive,
    String? tags,
    String? listingType,
    int? views,
    int? applicants,
    String? status,
  }) {
    return CombinedListingItem(
      id: id ?? this.id,
      listerId: listerId ?? this.listerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      tags: tags ?? this.tags,
      listingType: listingType ?? this.listingType,
      views: views ?? this.views,
      applicants: applicants ?? this.applicants,
      status: status ?? this.status,
    );
  }
}
