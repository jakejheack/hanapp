enum NotificationType { application, message, reply, job_confirmed, review_received, unknown, job_marked_done_by_doer, job_completed, }

class AppNotification {
  final int id;
  final NotificationType type;
  final String title;
  final String message;
  final int? relatedEntityId;
  final bool isRead;
  final DateTime timestamp;
  final String? senderName;
  final String? senderProfilePictureUrl;
  final int? senderId; // NEW: Add senderId here

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.relatedEntityId,
    this.isRead = false,
    required this.timestamp,
    this.senderName,
    this.senderProfilePictureUrl,
    this.senderId, // Initialize senderId
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse DateTime from UTC timestamp and convert to local
    DateTime parseDateTime(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return DateTime.now(); // Fallback to current time
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('AppNotification: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('AppNotification: Error parsing date "$value": $e. Using DateTime.now().');
        return DateTime.now(); // Fallback on parsing error
      }
    }

    NotificationType parsedType;
    try {
      parsedType = NotificationType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.unknown,
      );
    } catch (e) {
      parsedType = NotificationType.unknown;
    }
    return AppNotification(
      id: int.parse(json['id'].toString()),
      type: NotificationType.values.firstWhere((e) => e.toString().split('.').last == json['type'], orElse: () => NotificationType.message /* Default or error type */),
      title: json['title'],
      message: json['message'],
      relatedEntityId: json['related_entity_id'] != null ? int.parse(json['related_entity_id'].toString()) : null,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      timestamp: parseDateTime(json['timestamp']),
      senderName: json['sender_name'],
      senderProfilePictureUrl: json['sender_profile_picture_url'] as String?,
      senderId: json['sender_id'] != null ? int.parse(json['sender_id'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'related_entity_id': relatedEntityId,
      'is_read': isRead,
      'timestamp': timestamp.toIso8601String(),
      'sender_name': senderName,
      'sender_profile_picture_url': senderProfilePictureUrl,
      'sender_id': senderId,
    };
  }
}