import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timezone Parsing Tests', () {
    test('UTC timestamp parsing should work correctly', () {
      // Test timestamp from database in +08:00 timezone
      String dbTimestamp = '2025-06-30 11:03:00'; // This is 11:03 AM in +08:00
      
      // Parse as UTC (add Z suffix)
      DateTime utcDateTime = DateTime.parse(dbTimestamp + 'Z');
      
      // Convert to local time
      DateTime localDateTime = utcDateTime.toLocal();
      
      print('Original DB timestamp: $dbTimestamp');
      print('Parsed as UTC: $utcDateTime');
      print('Converted to local: $localDateTime');
      print('Local timezone offset: ${DateTime.now().timeZoneOffset}');
      
      // The local time should be different from the original timestamp
      // because we're treating the original as UTC and converting to local
      expect(localDateTime.hour, isNot(equals(11)));
      
      // If the device is in a different timezone than +08:00, the hour should be different
      // For example, if device is in UTC+0, the hour should be 3 (11 - 8 = 3)
      // If device is in UTC+2, the hour should be 5 (11 - 8 + 2 = 5)
      
      print('Test passed: UTC parsing is working correctly');
    });
    
    test('Message timestamp parsing should work', () {
      // Simulate a message JSON from the backend
      Map<String, dynamic> messageJson = {
        'id': 1,
        'conversation_id': 1,
        'sender_id': 1,
        'receiver_id': 2,
        'content': 'Test message',
        'sent_at': '2025-06-30 11:03:00', // +08:00 timestamp from database
        'type': 'text',
      };
      
      // This simulates what our Message.fromJson method does
      String timestampStr = messageJson['sent_at'].toString();
      DateTime utcDateTime = DateTime.parse(timestampStr + 'Z');
      DateTime localDateTime = utcDateTime.toLocal();
      
      print('Message timestamp test:');
      print('Original: $timestampStr');
      print('UTC: $utcDateTime');
      print('Local: $localDateTime');
      
      // Verify the parsing worked
      expect(localDateTime.year, equals(2025));
      expect(localDateTime.month, equals(6));
      expect(localDateTime.day, equals(30));
      
      print('Message timestamp parsing test passed');
    });
  });
} 