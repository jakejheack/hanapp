class DoerProfile {
  final String id;
  final String name;
  final String location;
  final String profileImageUrl;
  final double rating;
  final int reviewCount;
  final String bio;
  final List<String> skills;

  DoerProfile({
    required this.id,
    required this.name,
    required this.location,
    required this.profileImageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.bio = '',
    this.skills = const [],
  });

  factory DoerProfile.fromJson(Map<String, dynamic> json) {
    return DoerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String? ?? '',
      rating: double.parse(json['rating']?.toString() ?? '0.0'),
      reviewCount: int.parse(json['review_count']?.toString() ?? '0'),
      bio: json['bio'] as String? ?? '',
      skills: List<String>.from(json['skills'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'profile_image_url': profileImageUrl,
      'rating': rating,
      'review_count': reviewCount,
      'bio': bio,
      'skills': skills,
    };
  }
}