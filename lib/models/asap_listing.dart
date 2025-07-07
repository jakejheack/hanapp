import 'package:hanapp/models/user.dart'; // Assuming User model is defined

class AsapListing {
  final int id;
  final int listerId;
  final String title;
  final String? description;
  final double price;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? preferredDoerGender; // 'Male', 'Female', 'Any'
  final List<String>? picturesUrls; // List of image URLs
  final double? doerFee;
  final double? transactionFee;
  final double? totalAmount;
  final String? paymentMethod;
  final String status; // e.g., 'pending', 'searching', 'matched', 'completed'
  final bool isActive; // NEW: is_active field
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? lister; // Optional: To include lister's details when fetching listing
  final String listingType; // e.g., 'PUBLIC', 'ASAP'
  final String? listerFullName; // Added this field

  AsapListing({
    required this.id,
    required this.listerId,
    required this.title,
    this.description,
    required this.price,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.preferredDoerGender,
    this.picturesUrls,
    this.doerFee,
    this.transactionFee,
    this.totalAmount,
    this.paymentMethod,
    required this.status,
    required this.isActive, // NEW
    required this.createdAt,
    required this.updatedAt,
    this.lister,
    this.listingType = 'ASAP',
    this.listerFullName, // Include in constructor
  });

  factory AsapListing.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('AsapListing: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('AsapListing: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    return AsapListing(
      id: int.parse(json['id'].toString()),
      listerId: int.parse(json['lister_id'].toString()),
      title: json['title'] as String,
      description: json['description'] as String?,
      price: double.parse(json['price'].toString()),
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      locationAddress: json['location_address'] as String?,
      preferredDoerGender: json['preferred_doer_gender'] as String?,
      picturesUrls: (json['pictures_urls'] as List?)?.map((e) => e.toString()).toList(),
      doerFee: json['doer_fee'] != null ? double.parse(json['doer_fee'].toString()) : null,
      transactionFee: json['transaction_fee'] != null ? double.parse(json['transaction_fee'].toString()) : null,
      totalAmount: json['total_amount'] != null ? double.parse(json['total_amount'].toString()) : null,
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String,
      isActive: json['is_active'] == 1 || json['is_active'] == true, // NEW: Handle bool/int
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),

      listingType: json['listing_type'] as String? ?? 'ASAP',
      listerFullName: json['lister_full_name'] as String?, // Parse from JSON
      lister: json['lister_full_name'] != null
          ? User(
        id: int.parse(json['lister_id'].toString()),
        fullName: json['lister_full_name'] as String,
        email: '',
        role: '',
        profilePictureUrl: json['lister_profile_picture_url'] as String?,
      )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lister_id': listerId,
      'title': title,
      'description': description,
      'price': price,
      'latitude': latitude,
      'longitude': longitude,
      'location_address': locationAddress,
      'preferred_doer_gender': preferredDoerGender,
      'pictures_urls': picturesUrls,
      'doer_fee': doerFee,
      'transaction_fee': transactionFee,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'status': status,
      'is_active': isActive, // NEW
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AsapListing? copyWith({required bool isActive}) {}
}
