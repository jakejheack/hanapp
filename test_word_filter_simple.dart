import 'package:hanapp/utils/word_filter_service.dart';

void main() async {
  print('=== Testing Word Filter Service (API Only) ===');
  
  final wordFilterService = WordFilterService();
  
  // Test cases with explicit banned words
  final testCases = [
    'Hello world', // Should be clean
    'This is a test', // Should be clean
    'fuck you', // Should be banned
    'shit happens', // Should be banned
    'bitch please', // Should be banned
    'ass hole', // Should be banned
    'damn it', // Should be banned
    'hell no', // Should be banned
    'normal text with clean words', // Should be clean
    'fucker', // Should be banned
    'fucking', // Should be banned
    'shitty', // Should be banned
    'bitchy', // Should be banned
    'asshole', // Should be banned
    'dumbass', // Should be banned
    '', // Empty string
    '   ', // Whitespace only
  ];
  
  print('\n--- Testing Individual Words ---');
  for (final testCase in testCases) {
    print('\nTesting: "$testCase"');
    try {
      final result = await wordFilterService.findBannedWords(testCase);
      print('Result: $result');
      if (result.isNotEmpty) {
        print('✅ Banned words found: ${result['text']}');
      } else {
        print('✅ No banned words found');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }
  
  // Test multiple fields
  print('\n\n--- Testing Multiple Fields ---');
  final fields = {
    'title': 'Clean title',
    'description': 'This description has fuck and shit in it',
    'tags': 'normal, tags, here',
  };
  
  try {
    final bannedWordsByField = await wordFilterService.checkMultipleFields(fields);
    print('Banned words by field: $bannedWordsByField');
    if (bannedWordsByField.isNotEmpty) {
      print('✅ Found banned words in fields: ${bannedWordsByField.keys.toList()}');
    } else {
      print('❌ No banned words found in any field');
    }
  } catch (e) {
    print('❌ Error testing multiple fields: $e');
  }
  
  // Test with only banned words
  print('\n\n--- Testing Only Banned Words ---');
  final bannedFields = {
    'title': 'fuck shit',
    'description': 'bitch ass',
  };
  
  try {
    final bannedWordsByField = await wordFilterService.checkMultipleFields(bannedFields);
    print('Banned words by field: $bannedWordsByField');
    if (bannedWordsByField.isNotEmpty) {
      print('✅ Found banned words in fields: ${bannedWordsByField.keys.toList()}');
    } else {
      print('❌ No banned words found in any field');
    }
  } catch (e) {
    print('❌ Error testing banned fields: $e');
  }
} 