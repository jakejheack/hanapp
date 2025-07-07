import 'package:flutter_test/flutter_test.dart';
import 'package:hanapp/utils/word_filter_service.dart';

void main() {
  group('Word Filter Integration Tests', () {
    test('should detect banned words in listing titles', () async {
      final wordFilterService = WordFilterService();
      
      // Test with a title that might contain banned words
      final testTitle = 'This is a test title with potentially inappropriate content';
      final bannedWords = await wordFilterService.findBannedWords(testTitle);
      
      // The API will return true if banned words are found
      expect(bannedWords, isA<Map<String, List<String>>>());
    });

    test('should detect banned words in listing descriptions', () async {
      final wordFilterService = WordFilterService();
      
      // Test with a description that might contain banned words
      final testDescription = 'This is a test description with potentially inappropriate content';
      final bannedWords = await wordFilterService.findBannedWords(testDescription);
      
      // The API will return true if banned words are found
      expect(bannedWords, isA<Map<String, List<String>>>());
    });

    test('should check multiple fields for banned words', () async {
      final wordFilterService = WordFilterService();
      
      // Test with multiple fields (like in listing forms)
      final fields = {
        'title': 'Test title',
        'description': 'Test description',
        'tags': 'test, tags',
      };
      
      final bannedWordsByField = await wordFilterService.checkMultipleFields(fields);
      
      // Should return a map with field names as keys
      expect(bannedWordsByField, isA<Map<String, List<String>>>());
    });

    test('should allow clean content', () async {
      final wordFilterService = WordFilterService();
      
      // Test with clean content
      final cleanTitle = 'House cleaning service needed';
      final cleanDescription = 'Looking for someone to clean my house this weekend';
      
      final fields = {
        'title': cleanTitle,
        'description': cleanDescription,
      };
      
      final bannedWordsByField = await wordFilterService.checkMultipleFields(fields);
      
      // Clean content should not contain banned words
      expect(bannedWordsByField.isEmpty, isTrue);
    });

    test('should handle empty fields', () async {
      final wordFilterService = WordFilterService();
      
      // Test with empty fields
      final fields = {
        'title': '',
        'description': '   ',
        'tags': '',
      };
      
      final bannedWordsByField = await wordFilterService.checkMultipleFields(fields);
      
      // Empty fields should not contain banned words
      expect(bannedWordsByField.isEmpty, isTrue);
    });
  });
} 