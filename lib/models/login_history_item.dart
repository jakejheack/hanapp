class LoginHistoryItem {
  final String date;
  final String time;
  final String location;
  final String device;

  LoginHistoryItem({
    required this.date,
    required this.time,
    required this.location,
    required this.device,
  });

  factory LoginHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoginHistoryItem(
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      location: json['location'] ?? 'Unknown',
      device: json['device'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'time': time,
    'location': location,
    'device': device,
  };
} 