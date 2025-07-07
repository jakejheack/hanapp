import 'package:hanapp/utils/word_filter_service.dart';

void main() async {
  print('Testing Word Filter Service...');
  
  final wordFilterService = WordFilterService();
  
  // Test cases
  final testCases = [
    'Hello world', // Should be clean
    'This is a test', // Should be clean
    'fuck you', // Should be banned
    'shit happens', // Should be banned
    'normal text with clean words', // Should be clean
    '', // Empty string
    '   ', // Whitespace only
  ];
  
  for (final testCase in testCases) {
    print('\nTesting: "$testCase"');
    try {
      final result = await wordFilterService.findBannedWords(testCase);
      print('Result: $result');
      if (result.isNotEmpty) {
        print('Banned words found: ${result['text']}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
  
  // Test multiple fields
  print('\n\nTesting multiple fields...');
  final fields = {
    'title': 'Clean title',
    'description': 'This description has fuck in it',
    'tags': 'normal, tags, here',
  };
  
  try {
    final bannedWordsByField = await wordFilterService.checkMultipleFields(fields);
    print('Banned words by field: $bannedWordsByField');
  } catch (e) {
    print('Error testing multiple fields: $e');
  }
} 