class Application {
  final int id;
  final int? listingId;
  final String? listingType;
  final int? listerId;
  final int? doerId;
  final String? listingTitle;
  final String message; // Made non-nullable, with a default empty string
  final String? status;
  final DateTime? appliedAt;
  final int? conversationId;

  Application({
    required this.id,
    this.listingId,
    this.listingType,
    this.listerId,
    this.doerId,
    this.listingTitle,
    required this.message, // Ensure message is always provided or defaults to ''
    this.status,
    this.appliedAt,
    this.conversationId,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    print('Application.fromJson: Starting parsing for ID: ${json['id']}');

    DateTime? parseDateTime(dynamic value, String fieldName) {
      if (value == null || value is! String || value.isEmpty) {
        print('Application.fromJson: Warning: $fieldName is null, not a string, or empty. Value: $value');
        return null;
      }
      try {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(value + 'Z'); // Add Z to treat as UTC
        final localDateTime = utcDateTime.toLocal();
        print('Application.fromJson: Parsed UTC timestamp "$value" to local time: $localDateTime');
        return localDateTime;
      } catch (e) {
        print('Application.fromJson: Error parsing $fieldName date "$value": $e');
        return null;
      }
    }

    String? safeString(dynamic value, String fieldName) {
      if (value == null) {
        print('Application.fromJson: Warning: $fieldName is null. Returning null.');
        return null; // Keep as null if the field is genuinely optional
      }
      if (value is String) {
        return value;
      } else {
        print('Application.fromJson: Warning: $fieldName is not a string, type: ${value.runtimeType}. Converting to string. Value: $value');
        return value.toString();
      }
    }

    final int id = int.tryParse(json['id'].toString()) ?? 0;
    final int? listingId = int.tryParse(json['listing_id'].toString());
    final String? listingType = safeString(json['listing_type'], 'listing_type');
    final int? listerId = int.tryParse(json['lister_id'].toString());
    final int? doerId = int.tryParse(json['doer_id'].toString());
    final String? listingTitle = safeString(json['listing_title'], 'listing_title');
    // Ensure message is always a string, even if null from backend, default to empty
    final String message = safeString(json['message'], 'message') ?? '';
    final String? status = safeString(json['status'], 'status');
    final DateTime? appliedAt = parseDateTime(json['applied_at'], 'applied_at');
    final int? conversationId = int.tryParse(json['conversation_id'].toString());

    print('Application.fromJson: Finished parsing for ID: $id');
    return Application(
      id: id,
      listingId: listingId,
      listingType: listingType,
      listerId: listerId,
      doerId: doerId,
      listingTitle: listingTitle,
      message: message, // Now guaranteed to be non-null string
      status: status,
      appliedAt: appliedAt,
      conversationId: conversationId,
    );
  }

  Application copyWith({
    int? id,
    int? listingId,
    String? listingType,
    int? listerId,
    int? doerId,
    String? listingTitle,
    String? message,
    String? status,
    DateTime? appliedAt,
    int? conversationId,
  }) {
    return Application(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingType: listingType ?? this.listingType,
      listerId: listerId ?? this.listerId,
      doerId: doerId ?? this.doerId,
      listingTitle: listingTitle ?? this.listingTitle,
      message: message ?? this.message,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}
