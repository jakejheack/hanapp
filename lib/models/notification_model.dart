import 'package:intl/intl.dart';

class NotificationModel {
  final int id;
  final int userId; // The user who receives the notification
  final int? senderId; // The user who triggered the notification (e.g., applied, sent message)
  final String type; // e.g., 'application', 'message', 'review_reply', 'system'
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final int? associatedId; // e.g., application_id for 'application', review_id for 'review_reply'
  final int? listingId; // NEW: Added listingId to NotificationModel

  // Fields for linking to chat/conversation context
  final String? senderFullName;
  final String? senderProfilePictureUrl;
  final int? conversationIdForChat;
  final int? listerIdForChat; // The Lister ID of the conversation
  final int? doerIdForChat;   // The Doer ID of the conversation
  final String? relatedListingTitle; // Title of the listing related to the notification

  NotificationModel({
    required this.id,
    required this.userId,
    this.senderId,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.associatedId,
    this.listingId, // Initialize new field
    this.senderFullName,
    this.senderProfilePictureUrl,
    this.conversationIdForChat,
    this.listerIdForChat,
    this.doerIdForChat,
    this.relatedListingTitle,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime safeDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Backend sends timestamps in format "YYYY-MM-DD HH:MM:SS" (UTC time)
        // Use the same approach as working models: parse as UTC and convert to local
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('NotificationModel: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('NotificationModel: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    int? safeNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    String? safeNullableString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }


    return NotificationModel(
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      senderId: safeNullableInt(json['sender_id']),
      type: json['type'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: safeDateTime(json['created_at']),
      isRead: json['is_read'] == 1 || json['is_read'] == true, // Handle boolean or int
      associatedId: safeNullableInt(json['associated_id']),
      listingId: safeNullableInt(json['listing_id']), // Parse new field

      // Chat/Conversation related fields
      senderFullName: safeNullableString(json['sender_full_name']),
      senderProfilePictureUrl: safeNullableString(json['sender_profile_picture_url']),
      conversationIdForChat: safeNullableInt(json['conversation_id_for_chat']),
      listerIdForChat: safeNullableInt(json['lister_id_for_chat']),
      doerIdForChat: safeNullableInt(json['doer_id_for_chat']),
      relatedListingTitle: safeNullableString(json['related_listing_title']),
    );
  }

  get body => null;

  get status => null;

  // Method to create a copy of the NotificationModel object with updated fields
  NotificationModel copyWith({
    int? id,
    int? userId,
    int? senderId,
    String? type,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isRead,
    int? associatedId,
    int? listingId, // Add to copyWith
    String? senderFullName,
    String? senderProfilePictureUrl,
    int? conversationIdForChat,
    int? listerIdForChat,
    int? doerIdForChat,
    String? relatedListingTitle,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      associatedId: associatedId ?? this.associatedId,
      listingId: listingId ?? this.listingId, // Assign new field
      senderFullName: senderFullName ?? this.senderFullName,
      senderProfilePictureUrl: senderProfilePictureUrl ?? this.senderProfilePictureUrl,
      conversationIdForChat: conversationIdForChat ?? this.conversationIdForChat,
      listerIdForChat: listerIdForChat ?? this.listerIdForChat,
      doerIdForChat: doerIdForChat ?? this.doerIdForChat,
      relatedListingTitle: relatedListingTitle ?? this.relatedListingTitle,
    );
  }

  // Helper for 'time ago' display
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, Jamboree').format(createdAt);
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
