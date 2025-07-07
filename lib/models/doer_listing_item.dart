import 'package:intl/intl.dart'; // For date formatting

class DoerListingItem {
  final int id;
  final int listerId;
  final String title;
  final String? description;
  final double? price;
  final String? locationAddress;
  final DateTime createdAt;
  final String status;
  final String listingType; // 'ASAP' or 'PUBLIC'
  final String category; // 'Onsite', 'Hybrid', 'Remote' (for Public) or 'Onsite' (for ASAP)
  final String? listerFullName;
  final String? listerProfilePictureUrl;

  DoerListingItem({
    required this.id,
    required this.listerId,
    required this.title,
    this.description,
    this.price,
    this.locationAddress,
    required this.createdAt,
    required this.status,
    required this.listingType,
    required this.category,
    this.listerFullName,
    this.listerProfilePictureUrl,
  });

  factory DoerListingItem.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('DoerListingItem: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('DoerListingItem: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }
    
    return DoerListingItem(
      id: int.parse(json['id'].toString()),
      listerId: int.parse(json['lister_id'].toString()),
      title: json['title'] as String,
      description: json['description'] as String?,
      price: json['price'] != null ? double.parse(json['price'].toString()) : null,
      locationAddress: json['location_address'] as String?,
      createdAt: parseDateTime(json['created_at']),
      status: json['status'] as String,
      listingType: json['listing_type'] as String,
      category: json['category'] as String, // This will be 'Onsite' for ASAP listings from backend
      listerFullName: json['lister_full_name'] as String?,
      listerProfilePictureUrl: json['lister_profile_picture_url'] as String?,
    );
  }

  // Helper for displaying time ago (e.g., "2 hours ago")
  String getTimeAgo() {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  // Helper for displaying location and time
  String getLocationAndTimeDisplay() {
    String location = locationAddress?.split(',').first.trim() ?? 'Unknown Location';
    return '$location • ${getTimeAgo()}';
  }

  // Check if this is an ASAP listing
  bool get isAsap => listingType == 'ASAP';

  // Check if ASAP listing is about to expire (within 1 minute of 5-minute limit)
  bool get isAsapExpiringSoon {
    if (!isAsap) return false;
    final Duration timeSinceCreation = DateTime.now().difference(createdAt);
    return timeSinceCreation.inMinutes >= 4; // Show as expiring when 4+ minutes old
  }

  // Get remaining time before ASAP listing converts to public
  String get asapRemainingTime {
    if (!isAsap) return '';
    
    final Duration timeSinceCreation = DateTime.now().difference(createdAt);
    final int totalMinutes = 5;
    final int remainingMinutes = totalMinutes - timeSinceCreation.inMinutes;
    
    if (remainingMinutes <= 0) {
      return 'Converting to public...';
    } else if (remainingMinutes == 1) {
      return '1 minute left';
    } else {
      return '$remainingMinutes minutes left';
    }
  }

  // Get the urgency color for ASAP listings
  String get asapUrgencyColor {
    if (!isAsap) return '';
    
    final Duration timeSinceCreation = DateTime.now().difference(createdAt);
    final int remainingMinutes = 5 - timeSinceCreation.inMinutes;
    
    if (remainingMinutes <= 1) return 'red'; // Critical - about to expire
    if (remainingMinutes <= 2) return 'orange'; // Warning - expiring soon
    return 'green'; // Safe - still has time
  }
}
