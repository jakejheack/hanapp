import 'package:hanapp/models/user.dart'; // Assuming Lister is a User

class JobListing {
  final String id;
  final String title;
  final double price;
  final String description;
  final String location;
  final int views;
  final int applicants;
  final List<String> tags; // Assuming tags are a list of strings
  final String status; // e.g., 'active', 'complete', 'deleted', 'cancelled'

  JobListing({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.location,
    required this.views,
    required this.applicants,
    this.tags = const [],
    required this.status,
  });

  factory JobListing.fromJson(Map<String, dynamic> json) {
    return JobListing(
      id: json['id'].toString(),
      title: json['title'],
      price: double.parse(json['price'].toString()),
      description: json['description'],
      location: json['location'],
      views: int.parse(json['views'].toString()),
      applicants: int.parse(json['applicants'].toString()),
      tags: List<String>.from(json['tags'] as List? ?? []),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'description': description,
      'location': location,
      'views': views,
      'applicants': applicants,
      'tags': tags,
      'status': status,
    };
  }
}