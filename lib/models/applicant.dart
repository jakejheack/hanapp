class Applicant {
  final int applicationId; // NEW: ID of the application itself
  final int applicantId;
  final String fullName;
  final String email;
  final String? profilePictureUrl;
  final String? message; // NEW: Message from the applicant

  Applicant({
    required this.applicationId,
    required this.applicantId,
    required this.fullName,
    required this.email,
    this.profilePictureUrl,
    this.message,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      applicationId: int.parse(json['application_id'].toString()),
      applicantId: int.parse(json['applicant_id'].toString()),
      fullName: json['full_name'],
      email: json['email'],
      profilePictureUrl: json['profile_picture_url'],
      message: json['message_text'], // Map message_text from backend
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'application_id': applicationId,
      'applicant_id': applicantId,
      'full_name': fullName,
      'email': email,
      'profile_picture_url': profilePictureUrl,
      'message_text': message,
    };
  }
}