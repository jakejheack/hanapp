class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime sentAt;
  final String type; // e.g., 'text', 'system', 'location_share'
  final Map<String, dynamic>? extraData; // New field for location messages

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
    required this.type,
    this.extraData, // Initialize new field
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Parse the timestamp and ensure it's properly converted to local time
    DateTime sentAt;
    try {
      // Parse the timestamp string
      String timestampStr = json['sent_at'].toString();
      
      print('Message.fromJson: Starting with timestamp: $timestampStr');
      print('Message.fromJson: Current device timezone: ${DateTime.now().timeZoneOffset}');
      
      // Backend sends timestamps in format "2025-06-28 09:12:48" (UTC time)
      // Use the same approach as working models: parse as UTC and convert to local
      final utcDateTime = DateTime.parse(timestampStr + 'Z'); // Add Z to treat as UTC
      sentAt = utcDateTime.toLocal();
      
      print('Message.fromJson: Original: ${json['sent_at']}, Parsed as UTC: $utcDateTime, Converted to local: $sentAt');
      print('Message.fromJson: Current time: ${DateTime.now()}');
      print('Message.fromJson: Time difference: ${DateTime.now().difference(sentAt)}');
    } catch (e) {
      print('Message.fromJson: Error parsing timestamp: $e');
      // Fallback to current time if parsing fails
      sentAt = DateTime.now();
    }

    return Message(
      id: int.parse(json['id'].toString()),
      conversationId: int.parse(json['conversation_id'].toString()),
      senderId: int.parse(json['sender_id'].toString()),
      receiverId: int.parse(json['receiver_id'].toString()),
      content: json['content'] as String,
      sentAt: sentAt,
      type: json['type'] as String? ?? 'text', // Default to 'text' if not provided
      // Parse extra data if it exists
      extraData: json['extra_data'] != null
          ? Map<String, dynamic>.from(json['extra_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'sent_at': sentAt.toIso8601String(), // Ensure it's in ISO format for backend
      'type': type,
    };
    if (extraData != null) {
      data['extra_data'] = extraData;
    }
    return data;
  }
}
