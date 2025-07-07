import 'package:hanapp/models/review.dart';
import 'package:hanapp/models/user.dart'; // Assuming Lister is a User

class Listing {
  final int id;
  final int listerId;
  final String title;
  final double price;
  final String description;
  final String address;
  final String? category;
  final String? tags;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final String? listerName; // From JOIN in backend
  final String? listerProfilePictureUrl; // From JOIN in backend
  final int views; // NEW: Added views
  final int applicantsCount; // NEW: Added applicants count
  final double listerAverageRating; // NEW: Lister's average rating
  final int listerTotalReviews; // NEW: Lister's total reviews
  final List<Review>? listerReviews; // NEW: List of reviews for the lister

  Listing({
    required this.id,
    required this.listerId,
    required this.title,
    required this.price,
    required this.description,
    required this.address,
    this.category,
    this.tags,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    this.listerName,
    this.listerProfilePictureUrl,
    this.views = 0, // Default to 0
    this.applicantsCount = 0, // Default to 0
    this.listerAverageRating = 0.0, // Default to 0.0
    this.listerTotalReviews = 0, // Default to 0
    this.listerReviews,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('Listing: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('Listing: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    List<Review>? reviews;
    if (json['lister_reviews'] != null) {
      reviews = (json['lister_reviews'] as List)
          .map((reviewJson) => Review.fromJson(reviewJson))
          .toList();
    }
    return Listing(
      id: int.parse(json['id'].toString()),
      listerId: int.parse(json['lister_id'].toString()),
      title: json['title'] ?? '',
      price: double.parse(json['price'].toString()),
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      category: json['category'],
      tags: json['tags'],
      imageUrl: json['image_url'],
      status: json['status'] ?? 'active',
      createdAt: parseDateTime(json['created_at']),
      listerName: json['lister_name'],
      listerProfilePictureUrl: json['lister_profile_picture_url'],
      views: json['views'] != null ? int.parse(json['views'].toString()) : 0,
      applicantsCount: json['applicants_count'] != null ? int.parse(json['applicants_count'].toString()) : 0,
      listerAverageRating: json['lister_average_rating'] != null ? double.parse(json['lister_average_rating'].toString()) : 0.0,
      listerTotalReviews: json['lister_total_reviews'] != null ? int.parse(json['lister_total_reviews'].toString()) : 0,
      listerReviews: reviews,
    );
  }

  get applicationCount => null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lister_id': listerId,
      'title': title,
      'price': price,
      'description': description,
      'address': address,
      'category': category,
      'tags': tags,
      'image_url': imageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'lister_name': listerName,
      'lister_profile_picture_url': listerProfilePictureUrl,
      'views': views,
      'applicants_count': applicantsCount,
      'lister_average_rating': listerAverageRating,
      'lister_total_reviews': listerTotalReviews,
      'lister_reviews': listerReviews?.map((e) => e.toJson()).toList(),
    };
  }
}