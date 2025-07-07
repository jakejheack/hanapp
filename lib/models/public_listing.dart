import 'package:hanapp/models/user.dart'; // Assuming User model is defined

class PublicListing {
  final int id;
  final int listerId;
  final String title;
  final String? description;
  final double? price;
  final String category;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? preferredDoerGender;
  final List<String>? picturesUrls;
  final String? tags; // NEW: tags field
  final double? doerFee;
  final double? transactionFee;
  final double? totalAmount;
  final String? paymentMethod;
  final String status;
  final bool isActive; // NEW: is_active field
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? lister;
  final String listingType; // e.g., 'PUBLIC', 'ASAP'
  final String? listerFullName; // Added this field
  final String? listerProfilePictureUrl; // Added this field for completeness
  final String? listerAddressDetails; // Added this field for completeness

  PublicListing({
    required this.id,
    required this.listerId,
    required this.title,
    this.description,
    this.price,
    required this.category,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.preferredDoerGender,
    this.picturesUrls,
    this.tags, // NEW
    this.doerFee,
    this.transactionFee,
    this.totalAmount,
    this.paymentMethod,
    required this.status,
    required this.isActive, // NEW
    required this.createdAt,
    required this.updatedAt,
    this.lister,
    this.listingType = 'PUBLIC',
    this.listerFullName, // Include in constructor
    this.listerProfilePictureUrl, // Include in constructor
    this.listerAddressDetails, // Include in constructor

  });

  factory PublicListing.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('PublicListing: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('PublicListing: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    return PublicListing(
      id: int.parse(json['id'].toString()),
      listerId: int.tryParse(json['lister_id'].toString()) ?? 0,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: json['price'] != null ? double.parse(json['price'].toString()) : null,
      category: json['category'] as String,
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      locationAddress: json['location_address'] as String?,
      preferredDoerGender: json['preferred_doer_gender'] as String?,
      picturesUrls: (json['pictures_urls'] as List?)?.map((e) => e.toString()).toList(),
      tags: json['tags'] as String?, // NEW
      doerFee: json['doer_fee'] != null ? double.parse(json['doer_fee'].toString()) : null,
      transactionFee: json['transaction_fee'] != null ? double.parse(json['transaction_fee'].toString()) : null,
      totalAmount: json['total_amount'] != null ? double.parse(json['total_amount'].toString()) : null,
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String,
      isActive: json['is_active'] == 1 || json['is_active'] == true, // NEW: Handle bool/int
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),

      listingType: json['listing_type'] as String? ?? 'PUBLIC',
      listerFullName: json['lister_full_name'] as String?, // Parse from JSON
      listerProfilePictureUrl: json['lister_profile_picture_url'] as String?, // Parse from JSON
      listerAddressDetails: json['lister_address_details'] as String?,

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
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'location_address': locationAddress,
      'preferred_doer_gender': preferredDoerGender,
      'pictures_urls': picturesUrls,
      'tags': tags, // NEW
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

  // Optional: copyWith method for immutability
  PublicListing copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? listingType,
    double? price,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? tags,
    DateTime? createdAt,
    int? listerId,
    bool? isActive,
    String? listerFullName,
    String? listerProfilePictureUrl,
    String? listerAddressDetails,
  }) {
    return PublicListing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      listingType: listingType ?? this.listingType,
      price: price ?? this.price,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      listerId: listerId ?? this.listerId,
      isActive: isActive ?? this.isActive,
      listerFullName: listerFullName ?? this.listerFullName,
      listerProfilePictureUrl: listerProfilePictureUrl ?? this.listerProfilePictureUrl,
      listerAddressDetails: listerAddressDetails ?? this.listerAddressDetails, status: '', updatedAt: updatedAt,
    );
  }
}
