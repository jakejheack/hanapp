import 'package:intl/intl.dart';

class ConversationPreview {
  final int conversationId;
  final int listingId;
  final String listingType;
  final int listerId; // The Lister's ID in this conversation
  final int doerId;   // The Doer's ID in this conversation
  final int applicationId; // IMPORTANT: Made non-nullable if always expected

  final String listingTitle;
  final int otherUserId;
  final String otherUserName;
  final String? otherUserProfilePictureUrl;
  final String? otherUserAddressDetails;

  final String? lastMessageContent;
  final DateTime? lastMessageTimestamp;

  ConversationPreview({
    required this.conversationId,
    required this.listingId,
    required this.listingType,
    required this.listerId,
    required this.doerId,
    required this.applicationId, // Now required
    required this.listingTitle,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserProfilePictureUrl,
    this.otherUserAddressDetails,
    this.lastMessageContent,
    this.lastMessageTimestamp,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic value) {
      if (value == null) return 0; // Default to 0 if null/invalid
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String safeString(dynamic value, {String defaultValue = ''}) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    String? safeNullableString(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    DateTime? safeNullableDateTime(dynamic value) {
      if (value == null || (value is String && value.isEmpty)) {
        return null;
      }
      try {
        if (value is String) {
          // Backend sends timestamps in format "2025-06-28 09:12:48" (UTC time)
          // Use the same approach as working models: parse as UTC and convert to local
          final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
          return utcDateTime.toLocal();
        } else if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
        return null;
      } catch (e) {
        print('Error parsing date "$value": $e. Returning null.');
        return null;
      }
    }

    return ConversationPreview(
      conversationId: safeInt(json['conversation_id']),
      listingId: safeInt(json['listing_id']),
      listingType: safeString(json['listing_type']),
      listerId: safeInt(json['lister_id']),
      doerId: safeInt(json['doer_id']),
      applicationId: safeInt(json['application_id']), // Use safeInt, now non-nullable
      listingTitle: safeString(json['listing_title']),
      otherUserId: safeInt(json['other_user_id']),
      otherUserName: safeString(json['other_user_name']),
      otherUserProfilePictureUrl: safeNullableString(json['other_user_profile_picture_url']),
      otherUserAddressDetails: safeNullableString(json['other_user_address_details']),
      lastMessageContent: safeNullableString(json['last_message_content']),
      lastMessageTimestamp: safeNullableDateTime(json['last_message_timestamp']),
    );
  }

  String getLastMessageTimeAgo() {
    if (lastMessageTimestamp == null) {
      return '';
    }
    final now = DateTime.now();
    final difference = now.difference(lastMessageTimestamp!);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, Jamboree').format(lastMessageTimestamp!);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
