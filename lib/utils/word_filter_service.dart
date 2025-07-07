import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';

class WordFilterService {
  static final WordFilterService _instance = WordFilterService._internal();
  factory WordFilterService() => _instance;
  WordFilterService._internal();

  /// Check if the given text contains banned words
  /// Returns a map with banned words and their locations
  Future<Map<String, List<String>>> findBannedWords(String text) async {
    if (text.trim().isEmpty) return {};

    print('WordFilterService: Checking text: "$text"');

    try {
      // Clean and encode the text for URL
      final cleanText = Uri.encodeComponent(text.trim());
      final url = 'https://autosell.io/data/filter/$cleanText';
      
      print('WordFilterService: Calling API: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('WordFilterService: API response status: ${response.statusCode}');
      print('WordFilterService: API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // The API returns true if banned words are found
        if (data is bool && data == true) {
          print('WordFilterService: API detected banned words');
          // Since the API detected banned words, we'll return a generic message
          // The API doesn't return specific words, so we'll indicate that banned words were found
          return {'text': ['inappropriate content detected']};
        }
        print('WordFilterService: API says no banned words');
      } else {
        print('WordFilterService: HTTP error ${response.statusCode}');
        // If API is unavailable, we should probably block the content to be safe
        // or you can change this to return {} to allow content when API is down
        return {'text': ['content blocked - API unavailable']};
      }
    } catch (e) {
      print('WordFilterService: Error checking banned words: $e');
      // If there's an error, we should probably block the content to be safe
      // or you can change this to return {} to allow content when there's an error
      return {'text': ['content blocked - error occurred']};
    }

    return {};
  }

  /// Check if the given text contains banned words (legacy method)
  /// Returns true if banned words are found, false otherwise
  Future<bool> containsBannedWords(String text) async {
    final bannedWords = await findBannedWords(text);
    return bannedWords.isNotEmpty;
  }

  /// Check multiple text fields for banned words
  /// Returns a map with field names as keys and banned words as values
  Future<Map<String, List<String>>> checkMultipleFields(Map<String, String> fields) async {
    final results = <String, List<String>>{};
    
    print('WordFilterService: Checking multiple fields: ${fields.keys.toList()}');
    
    for (final entry in fields.entries) {
      if (entry.value.isNotEmpty) {
        print('WordFilterService: Checking field "${entry.key}": "${entry.value}"');
        final bannedWords = await findBannedWords(entry.value);
        if (bannedWords.isNotEmpty) {
          results[entry.key] = bannedWords['text'] ?? [];
          print('WordFilterService: Found banned words in "${entry.key}": ${bannedWords['text']}');
        }
      }
    }
    
    print('WordFilterService: Final results: $results');
    return results;
  }

  /// Get a list of fields that contain banned words
  Future<List<String>> getBannedFields(Map<String, String> fields) async {
    final results = await checkMultipleFields(fields);
    return results.keys.toList();
  }

  /// Validate a single field and return error message if banned words found
  Future<String?> validateField(String fieldName, String text) async {
    final bannedWords = await findBannedWords(text);
    if (bannedWords.isNotEmpty) {
      final words = bannedWords['text']?.join(', ') ?? '';
      return 'The $fieldName contains inappropriate content: $words';
    }
    return null;
  }

  /// Validate multiple fields and return error messages
  Future<Map<String, String?>> validateFields(Map<String, String> fields) async {
    final results = <String, String?>{};
    
    for (final entry in fields.entries) {
      results[entry.key] = await validateField(entry.key, entry.value);
    }
    
    return results;
  }
} 