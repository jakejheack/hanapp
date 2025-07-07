# Word Filter Implementation

This document describes the implementation of word filtering functionality in the HanApp Flutter application.

## Overview

The word filtering system uses the `https://autosell.io/data/filter/(words)` API to detect and block inappropriate content in user-generated text. The system is integrated into multiple parts of the application to ensure content safety.

## Components

### 1. WordFilterService (`lib/utils/word_filter_service.dart`)

The core service that handles API communication and word filtering logic.

**Key Methods:**
- `findBannedWords(String text)` - Checks a single text field for banned words
- `checkMultipleFields(Map<String, String> fields)` - Checks multiple text fields
- `containsBannedWords(String text)` - Legacy method that returns boolean
- `validateField(String fieldName, String text)` - Validates a single field and returns error message
- `validateFields(Map<String, String> fields)` - Validates multiple fields

**API Integration:**
- Uses `https://autosell.io/data/filter/(words)` endpoint
- Returns `true` if banned words are detected, `false` otherwise
- Handles API errors gracefully by blocking content when API is unavailable

### 2. BannedWordsDialog (`lib/widgets/banned_words_dialog.dart`)

A professional dialog component that displays when banned words are detected.

**Features:**
- Clean, modern UI design
- Shows which fields contain inappropriate content
- Non-dismissible by default (user must acknowledge)
- Responsive layout with proper overflow handling
- Professional color scheme matching app theme

## Integration Points

### 1. Listing Creation Forms

**Public Listing Form (`lib/screens/lister/public_listing_form.dart`)**
- Filters: title, description, requirements, location
- Shows dialog when banned words detected
- Prevents form submission

**ASAP Listing Form (`lib/screens/lister/asap_listing_form.dart`)**
- Filters: title, description, requirements, location
- Shows dialog when banned words detected
- Prevents form submission

**Combined Listing Form (`lib/screens/lister/combined_listing_form.dart`)**
- Filters: title, description, requirements, location
- Shows dialog when banned words detected
- Prevents form submission

### 2. Chat Messages

**Chat Screen (`lib/screens/chat_screen.dart`)**
- Filters: message content
- Shows dialog when banned words detected
- Prevents message sending
- Integrated into `_sendMessage()` method

**Chat View Model (`lib/viewmodels/chat_view_model.dart`)**
- Filters: message content
- Returns structured response with banned words information
- Updated to handle word filtering in `sendMessage()` method

## Implementation Details

### API Response Handling

The word filter API returns a boolean value:
- `true` = banned words detected
- `false` = no banned words found

Since the API doesn't return specific banned words, the system shows a generic message when inappropriate content is detected.

### Error Handling

The system handles various error scenarios:
1. **API Unavailable**: Blocks content to be safe
2. **Network Errors**: Blocks content to be safe
3. **Invalid Responses**: Blocks content to be safe

This conservative approach ensures content safety even when the external API is down.

### User Experience

1. **Real-time Checking**: Words are checked as users type
2. **Clear Feedback**: Professional dialog shows exactly what's wrong
3. **Non-blocking**: Users can easily dismiss and try again
4. **Consistent UI**: Same dialog design across all forms

## Testing

### Manual Testing

1. **Clean Content**: Try submitting forms with normal, appropriate content
2. **Banned Words**: Try submitting forms with known inappropriate words
3. **Edge Cases**: Test with empty fields, whitespace-only content
4. **API Errors**: Test behavior when API is unavailable

### Automated Testing

Run the test files:
```bash
flutter test test_word_filter.dart
flutter test test_word_filter_simple.dart
flutter test test_word_filter_chat.dart
```

## Configuration

### API Endpoint

The word filter API endpoint is configured in `WordFilterService`:
```dart
final url = 'https://autosell.io/data/filter/$cleanText';
```

### Error Handling Strategy

The current implementation blocks content when the API is unavailable. To change this behavior, modify the error handling in `findBannedWords()` method:

```dart
// Current: Block content when API is down
return {'text': ['content blocked - API unavailable']};

// Alternative: Allow content when API is down
return {};
```

## Future Enhancements

1. **Caching**: Cache API responses to reduce API calls
2. **Local Filtering**: Add basic local filtering for common words
3. **User Feedback**: Allow users to report false positives
4. **Custom Lists**: Support custom banned word lists per organization
5. **Performance**: Implement batch checking for multiple fields

## Troubleshooting

### Common Issues

1. **Dialog Not Showing**: Check if `BannedWordsDialog` is properly imported
2. **API Errors**: Verify network connectivity and API endpoint availability
3. **Form Not Blocking**: Ensure word filtering is called before form submission
4. **UI Overflow**: Check dialog layout and text wrapping

### Debug Information

Enable debug logging by checking console output:
```
WordFilterService: Checking text: "user input"
WordFilterService: API response status: 200
WordFilterService: API response body: true/false
```

## Security Considerations

1. **Content Safety**: The system prioritizes content safety over user convenience
2. **API Reliability**: Conservative error handling when API is unavailable
3. **User Privacy**: No user data is stored or logged by the word filter
4. **Rate Limiting**: Consider implementing rate limiting for API calls

## Maintenance

### Regular Tasks

1. **Monitor API Health**: Check API endpoint availability
2. **Review Error Logs**: Monitor for API failures or unusual patterns
3. **Update Dependencies**: Keep HTTP package and other dependencies updated
4. **Test Functionality**: Regularly test word filtering across all forms

### Performance Monitoring

1. **API Response Times**: Monitor API call performance
2. **User Experience**: Track user feedback on filtering accuracy
3. **Error Rates**: Monitor API error rates and adjust error handling if needed 