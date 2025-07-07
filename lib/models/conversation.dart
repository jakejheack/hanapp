class Conversation {
  final int conversationId;
  final int listingId;
  final String listingType;
  final int listerId;
  final int doerId;
  final int? applicationId;
  final String? applicationStatus;
  final DateTime? projectStartDate;
  final String? listingLocationAddress;
  final String? listingTitle;
  final String? listerFullName;
  final String? listerProfilePictureUrl;
  final String? listerAddressDetails;
  final String? doerFullName;
  final String? doerProfilePictureUrl;
  final String? doerAddressDetails;

  Conversation({
    required this.conversationId,
    required this.listingId,
    required this.listingType,
    required this.listerId,
    required this.doerId,
    this.applicationId,
    this.applicationStatus,
    this.projectStartDate,
    this.listingLocationAddress,
    this.listingTitle,
    this.listerFullName,
    this.listerProfilePictureUrl,
    this.listerAddressDetails,
    this.doerFullName,
    this.doerProfilePictureUrl,
    this.doerAddressDetails,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationId: int.parse(json['conversation_id'].toString()),
      listingId: int.parse(json['listing_id'].toString()),
      listingType: json['listing_type'] as String,
      listerId: int.parse(json['lister_id'].toString()),
      doerId: int.parse(json['doer_id'].toString()),
      applicationId: json['application_id'] != null ? int.parse(json['application_id'].toString()) : null,
      applicationStatus: json['application_status'] as String?,
      projectStartDate: json['project_start_date'] != null
          ? DateTime.tryParse(json['project_start_date'].toString())?.toLocal()
          : null,
      listingLocationAddress: json['listing_location_address'] as String?,
      listingTitle: json['listing_title'] as String?,
      listerFullName: json['lister_full_name'] as String?,
      listerProfilePictureUrl: json['lister_profile_picture_url'] as String?,
      listerAddressDetails: json['lister_address_details'] as String?,
      doerFullName: json['doer_full_name'] as String?,
      doerProfilePictureUrl: json['doer_profile_picture_url'] as String?,
      doerAddressDetails: json['doer_address_details'] as String?,
    );
  }

  // Helper method to get the 'other' user's full name based on currentUserId
  String? getOtherUserFullName(int currentUserId) {
    if (currentUserId == listerId) {
      return doerFullName;
    } else if (currentUserId == doerId) {
      return listerFullName;
    }
    return null; // Should not happen if currentUserId is part of the conversation
  }

  // Helper method to get the 'other' user's address based on currentUserId
  String? getOtherUserAddress(int currentUserId) {
    if (currentUserId == listerId) {
      return doerAddressDetails;
    } else if (currentUserId == doerId) {
      return listerAddressDetails;
    }
    return null;
  }

  // Helper method to get the 'other' user's profile picture URL based on currentUserId
  String? getOtherUserProfilePictureUrl(int currentUserId) {
    if (currentUserId == listerId) {
      return doerProfilePictureUrl;
    } else if (currentUserId == doerId) {
      return listerProfilePictureUrl;
    }
    return null;
  }
}
