class AppSetting {
  final String category;
  final String description;
  final DateTime lastUpdatedAt;

  AppSetting({
    required this.category,
    required this.description,
    required this.lastUpdatedAt,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) {
    return AppSetting(
      category: json['category'] as String,
      description: json['description'] as String,
      lastUpdatedAt: DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'updated_at': lastUpdatedAt.toIso8601String(),
    };
  }
} 