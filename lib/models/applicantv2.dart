class Applicant {
  final int id;
  final int listingId;
  final String listingType;
  final int listerId;
  final int doerId;
  final String message;
  final String status;
  final DateTime appliedAt;
  final String listingTitle;
  final ApplicantDoer? doer;

  Applicant({
    required this.id,
    required this.listingId,
    required this.listingType,
    required this.listerId,
    required this.doerId,
    required this.message,
    required this.status,
    required this.appliedAt,
    required this.listingTitle,
    this.doer,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    print('Applicant.fromJson: Starting parsing for ID: ${json['id']}');

    DateTime parseDateTime(dynamic value, String fieldName) {
      if (value == null || value is! String || value.isEmpty) {
        print('Applicant.fromJson: Warning: $fieldName is null, not a string, or empty. Using DateTime.now(). Value: $value');
        return DateTime.now();
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('Applicant.fromJson: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('Applicant.fromJson: Error parsing $fieldName date "$value": $e. Using DateTime.now().');
        return DateTime.now();
      }
    }

    String safeString(dynamic value, String fieldName) {
      if (value == null) {
        print('Applicant.fromJson: Warning: $fieldName is null. Using empty string.');
        return '';
      }
      if (value is String) {
        return value;
      } else {
        print('Applicant.fromJson: Warning: $fieldName is not a string, type: ${value.runtimeType}. Converting to string. Value: $value');
        return value.toString();
      }
    }

    final int id = int.tryParse(json['id'].toString()) ?? 0;
    final int listingId = int.tryParse(json['listing_id'].toString()) ?? 0;
    final String listingType = safeString(json['listing_type'], 'listing_type');
    final int listerId = int.tryParse(json['lister_id'].toString()) ?? 0;
    final int doerId = int.tryParse(json['doer_id'].toString()) ?? 0;
    final String message = safeString(json['message'], 'message');
    final String status = safeString(json['status'], 'status');
    final DateTime appliedAt = parseDateTime(json['applied_at'], 'applied_at');
    final String listingTitle = safeString(json['listing_title'], 'listing_title');

    final ApplicantDoer? doer = json['doer'] != null
        ? ApplicantDoer.fromJson(json['doer'] as Map<String, dynamic>)
        : null;

    print('Applicant.fromJson: Finished parsing for ID: $id');
    return Applicant(
      id: id,
      listingId: listingId,
      listingType: listingType,
      listerId: listerId,
      doerId: doerId,
      message: message,
      status: status,
      appliedAt: appliedAt,
      listingTitle: listingTitle,
      doer: doer,
    );
  }
}

class ApplicantDoer {
  final int id;
  final String fullName;
  final String profilePictureUrl;

  ApplicantDoer({
    required this.id,
    required this.fullName,
    required this.profilePictureUrl,
  });

  factory ApplicantDoer.fromJson(Map<String, dynamic> json) {
    print('ApplicantDoer.fromJson: Starting parsing for ID: ${json['id']}');

    String safeString(dynamic value, String fieldName) {
      if (value == null) {
        print('ApplicantDoer.fromJson: Warning: $fieldName is null. Using empty string.');
        return '';
      }
      if (value is String) {
        return value;
      } else {
        print('ApplicantDoer.fromJson: Warning: $fieldName is not a string, type: ${value.runtimeType}. Converting to string. Value: $value');
        return value.toString();
      }
    }

    final int id = int.tryParse(json['id'].toString()) ?? 0;
    final String fullName = safeString(json['full_name'], 'full_name');
    final String profilePictureUrl = safeString(json['profile_picture_url'], 'profile_picture_url');

    print('ApplicantDoer.fromJson: Finished parsing for ID: $id');
    return ApplicantDoer(
      id: id,
      fullName: fullName,
      profilePictureUrl: profilePictureUrl,
    );
  }
}
