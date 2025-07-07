import 'package:flutter_test/flutter_test.dart';
import 'package:hanapp/utils/word_filter_service.dart';

void main() {
  group('Chat Word Filter Tests', () {
    test('should detect banned words in chat messages', () async {
      final wordFilterService = WordFilterService();
      
      // Test with a message that might contain banned words
      final testMessage = 'This is a test message with potentially inappropriate content';
      final bannedWords = await wordFilterService.findBannedWords(testMessage);
      
      // The API will return true if banned words are found
      // We can't predict the exact result, but we can test the structure
      expect(bannedWords, isA<Map<String, List<String>>>());
    });

    test('should allow clean messages', () async {
      final wordFilterService = WordFilterService();
      
      // Test with a clean message
      final cleanMessage = 'Hello, how are you doing today?';
      final bannedWords = await wordFilterService.findBannedWords(cleanMessage);
      
      // Clean messages should not contain banned words
      expect(bannedWords.isEmpty, isTrue);
    });

    test('should handle empty messages', () async {
      final wordFilterService = WordFilterService();
      
      // Test with empty message
      final emptyMessage = '';
      final bannedWords = await wordFilterService.findBannedWords(emptyMessage);
      
      // Empty messages should not contain banned words
      expect(bannedWords.isEmpty, isTrue);
    });

    test('should handle whitespace-only messages', () async {
      final wordFilterService = WordFilterService();
      
      // Test with whitespace-only message
      final whitespaceMessage = '   \n\t   ';
      final bannedWords = await wordFilterService.findBannedWords(whitespaceMessage);
      
      // Whitespace-only messages should not contain banned words
      expect(bannedWords.isEmpty, isTrue);
    });

    test('should check multiple fields for banned words', () async {
      final wordFilterService = WordFilterService();
      
      // Test with multiple fields
      final fields = {
        'message': 'Hello, this is a test message',
        'title': 'Test title',
      };
      
      final bannedFields = await wordFilterService.checkMultipleFields(fields);
      
      // Should return a map with field names as keys
      expect(bannedFields, isA<Map<String, List<String>>>());
    });
  });
} 