import 'package:flutter/material.dart';
import 'package:hanapp/utils/word_filter_service.dart';

class WordFilterValidator {
  static final WordFilterService _wordFilterService = WordFilterService();

  /// Creates a validator function that checks for banned words
  /// Returns null if valid, error message if banned words found
  static Future<String?> Function(String?) createValidator(String fieldName) {
    return (String? value) async {
      if (value == null || value.trim().isEmpty) {
        return null; // Empty values are handled by required validators
      }

      try {
        final bannedWords = await _wordFilterService.findBannedWords(value);
        if (bannedWords.isNotEmpty) {
          final words = bannedWords['text']?.join(', ') ?? '';
          return 'The $fieldName contains inappropriate content: $words';
        }
        return null;
      } catch (e) {
        print('WordFilterValidator: Error validating $fieldName: $e');
        return null; // Allow if validation fails (fail-safe)
      }
    };
  }

  /// Creates a debounced validator that waits before checking
  /// Useful for real-time validation without too many API calls
  static Future<String?> Function(String?) createDebouncedValidator(
    String fieldName, {
    Duration debounceTime = const Duration(milliseconds: 500),
  }) {
    return (String? value) async {
      if (value == null || value.trim().isEmpty) {
        return null;
      }

      // Add a small delay to avoid too many API calls
      await Future.delayed(debounceTime);

      try {
        final bannedWords = await _wordFilterService.findBannedWords(value);
        if (bannedWords.isNotEmpty) {
          final words = bannedWords['text']?.join(', ') ?? '';
          return 'The $fieldName contains inappropriate content: $words';
        }
        return null;
      } catch (e) {
        print('WordFilterValidator: Error validating $fieldName: $e');
        return null;
      }
    };
  }

  /// Simple validator that returns immediately (for immediate feedback)
  /// Use this for basic validation without API calls
  static String? Function(String?) createSimpleValidator(String fieldName) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return null;
      }

      // Basic checks for obvious inappropriate content
      final lowerValue = value.toLowerCase();
      final obviousBannedWords = [
        'fuck', 'shit', 'bitch', 'ass', 'damn', 'hell',
        // Add more obvious words that should be caught immediately
      ];

      for (final word in obviousBannedWords) {
        if (lowerValue.contains(word)) {
          return 'The $fieldName contains inappropriate content. Please revise your text.';
        }
      }

      return null;
    };
  }
} 