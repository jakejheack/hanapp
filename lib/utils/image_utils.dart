import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageUtils {
  /// Convert a file to base64 string
  static Future<String> fileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Convert an XFile to base64 string
  static Future<String> xFileToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Check if a string is a base64 image
  static bool isBase64Image(String? imageString) {
    if (imageString == null || imageString.isEmpty) return false;
    
    // Check if it starts with data:image (data URL format)
    if (imageString.startsWith('data:image')) return true;
    
    // Check if it's a base64 string (not a URL)
    if (!imageString.startsWith('http') && !imageString.startsWith('file://')) {
      // If it's not a URL and reasonably long, check if it looks like base64
      if (imageString.length > 50) {
        // Check if it contains only base64 characters
        final base64Regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
        if (base64Regex.hasMatch(imageString)) {
          // Don't try to decode truncated strings - just return true if it looks like base64
          return true;
        }
      }
    }
    
    return false;
  }

  /// Create an ImageProvider from a profile picture URL, file path, or base64 string
  static ImageProvider<Object>? createProfileImageProvider(String? profilePictureUrl) {
    if (profilePictureUrl == null || profilePictureUrl.isEmpty) {
      // Return null instead of non-existent asset, let the UI handle the fallback
      return null;
    }

    // If it's a URL (starts with http/https)
    if (profilePictureUrl.startsWith('http')) {
      try {
        return CachedNetworkImageProvider(profilePictureUrl);
      } catch (e) {
        debugPrint('Error creating CachedNetworkImageProvider: $e');
        return null;
      }
    }
    
    // If it's a local file path (starts with uploads/)
    if (profilePictureUrl.startsWith('uploads/')) {
      try {
        // Use the file serving endpoint
        final fullUrl = 'https://autosell.io/api/serve_file.php?path=${Uri.encodeComponent(profilePictureUrl)}';
        return CachedNetworkImageProvider(fullUrl);
      } catch (e) {
        debugPrint('Error creating CachedNetworkImageProvider for local file: $e');
        return null;
      }
    }

    // If it's base64 data (legacy support)
    if (isBase64Image(profilePictureUrl)) {
      try {
        // Remove data:image prefix if present
        String base64Data = profilePictureUrl.replaceFirst(
          RegExp(r'data:image/[^;]+;base64,'), 
          ''
        );
        
        // Check if the base64 string is truncated
        if (base64Data.length % 4 != 0) {
          debugPrint('ImageUtils: WARNING: Base64 string appears to be truncated (length: ${base64Data.length})');
          debugPrint('ImageUtils: Cannot decode truncated base64 image data');
          return null; // Return null for truncated data instead of trying to decode it
        }
        
        // Add padding if needed (this should not be needed if we handle truncation above)
        while (base64Data.length % 4 != 0) {
          base64Data += '=';
        }
        
        final bytes = base64Decode(base64Data);
        debugPrint('ImageUtils: Decoded ${bytes.length} bytes from base64');
        
        // Check if the bytes look like a valid image
        if (bytes.length < 10) {
          debugPrint('ImageUtils: Decoded bytes too short to be a valid image');
          return null;
        }
        
        // Check the first few bytes to identify image format
        if (bytes.length >= 4) {
          final header = bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
          debugPrint('ImageUtils: Image header bytes: $header');
          
          // Check for common image format signatures
          if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
            debugPrint('ImageUtils: Detected JPEG format');
          } else if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
            debugPrint('ImageUtils: Detected PNG format');
            // Additional PNG validation
            if (bytes.length >= 8) {
              // Check for PNG signature: 89 50 4E 47 0D 0A 1A 0A
              if (bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
                debugPrint('ImageUtils: PNG signature is valid');
              } else {
                debugPrint('ImageUtils: PNG signature is invalid - data may be corrupted');
              }
            }
          } else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
            debugPrint('ImageUtils: Detected GIF format');
          } else {
            debugPrint('ImageUtils: Unknown image format or corrupted data');
          }
        }
        
        try {
          return MemoryImage(bytes);
        } catch (e) {
          debugPrint('Error creating MemoryImage: $e');
          debugPrint('ImageUtils: PNG appears to be corrupted or incomplete');
          return null;
        }
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return null;
      }
    }
    
    // If none of the above, return null
    return null;
  }

  /// Create an ImageProvider from a selected file (for preview)
  static ImageProvider<Object>? createSelectedImageProvider(XFile? selectedFile) {
    if (selectedFile == null) return null;
    
    if (kIsWeb) {
      return NetworkImage(selectedFile.path);
    } else {
      return FileImage(File(selectedFile.path));
    }
  }

  /// Get the appropriate ImageProvider for profile display
  /// Prioritizes selected image, then stored image, then default
  static ImageProvider<Object>? getProfileImageProvider({
    XFile? selectedFile,
    String? storedImageUrl,
  }) {
    // First priority: newly selected image
    if (selectedFile != null) {
      return createSelectedImageProvider(selectedFile);
    }
    
    // Second priority: stored image (base64 or URL)
    if (storedImageUrl != null && storedImageUrl.isNotEmpty) {
      return createProfileImageProvider(storedImageUrl);
    }
    
    // Fallback: return null, let UI handle with default icon
    return null;
  }

  /// Test method to verify profile picture loading
  static void testProfilePictureLoading(String? profilePictureUrl) {
    print('ImageUtils: Testing profile picture loading');
    print('ImageUtils: URL: $profilePictureUrl');
    
    if (profilePictureUrl == null || profilePictureUrl.isEmpty) {
      print('ImageUtils: No profile picture URL provided');
      return;
    }
    
    // Debug base64 detection
    if (!profilePictureUrl.startsWith('http') && !profilePictureUrl.startsWith('file://')) {
      print('ImageUtils: Length: ${profilePictureUrl.length}');
      print('ImageUtils: Starts with http: ${profilePictureUrl.startsWith('http')}');
      print('ImageUtils: Starts with file://: ${profilePictureUrl.startsWith('file://')}');
      
      // Check if it looks like a truncated base64 string
      if (profilePictureUrl.length % 4 != 0) {
        print('ImageUtils: WARNING: Base64 string length is not a multiple of 4 (${profilePictureUrl.length % 4} remainder)');
        print('ImageUtils: This might indicate the string is truncated');
      }
      
      // Show first and last few characters
      if (profilePictureUrl.length > 20) {
        print('ImageUtils: First 20 chars: ${profilePictureUrl.substring(0, 20)}');
        print('ImageUtils: Last 20 chars: ${profilePictureUrl.substring(profilePictureUrl.length - 20)}');
      }
    }
    
    if (isBase64Image(profilePictureUrl)) {
      print('ImageUtils: Detected base64 image');
      print('ImageUtils: Base64 length: ${profilePictureUrl.length}');
    } else {
      print('ImageUtils: Detected URL image');
    }
    
    final imageProvider = createProfileImageProvider(profilePictureUrl);
    if (imageProvider != null) {
      print('ImageUtils: Successfully created image provider: ${imageProvider.runtimeType}');
    } else {
      print('ImageUtils: Failed to create image provider');
    }
  }
} 