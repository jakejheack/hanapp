import 'package:hanapp/models/user.dart'; // Assuming your User model exists

class Application {
  final int id;
  final int listingId;
  final int applicantUserId;
  final String status;
  final String? message;
  final DateTime appliedAt;
  final String applicantName;
  final String? applicantProfilePictureUrl;
  final double applicantRating;
  final String? applicantAddressDetails;

  Application({
    required this.id,
    required this.listingId,
    required this.applicantUserId,
    required this.status,
    this.message,
    required this.appliedAt,
    required this.applicantName,
    this.applicantProfilePictureUrl,
    required this.applicantRating,
    this.applicantAddressDetails,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      id: int.parse(json['id'].toString()),
      listingId: int.parse(json['listing_id'].toString()),
      applicantUserId: int.parse(json['applicant_user_id'].toString()),
      status: json['status'] as String,
      message: json['message'] as String?,
      appliedAt: DateTime.parse(json['applied_at']).toLocal(),
      applicantName: json['applicant_name'] as String,
      applicantProfilePictureUrl: json['applicant_profile_picture_url'] as String?,
      applicantRating: double.parse(json['applicant_rating'].toString()),
      applicantAddressDetails: json['applicant_address_details'] as String?,
    );
  }
}
