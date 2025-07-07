import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/models/video.dart';
import 'package:hanapp/utils/api_config.dart';

class VideoService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Fetch all active videos from the API
  Future<List<Video>> getActiveVideos() async {
    try {
      final url = Uri.parse('$baseUrl/videos/get_active_videos.php');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final videosJson = json.decode(response.body);
        
        if (videosJson['success'] == true && videosJson['videos'] is List) {
          return (videosJson['videos'] as List)
              .map((videoJson) => Video.fromJson(videoJson))
              .toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      print('Error in getActiveVideos: $e');
      return [];
    }
  }

  /// Fetch videos by category
  Future<List<Video>> getVideosByCategory(String category) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos/get_videos_by_category.php?category=$category'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true) {
          final List<dynamic> videosJson = data['videos'] ?? [];
          return videosJson.map((json) => Video.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch videos');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error fetching videos by category: $e');
    }
  }

  /// Fetch all videos (including inactive)
  Future<List<Video>> getAllVideos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos/get_all_videos.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true) {
          final List<dynamic> videosJson = data['videos'] ?? [];
          return videosJson.map((json) => Video.fromJson(json)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch videos');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error fetching all videos: $e');
    }
  }

  /// Get video categories
  Future<List<String>> getVideoCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos/get_categories.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true) {
          final List<dynamic> categoriesJson = data['categories'] ?? [];
          return categoriesJson.map((json) => json.toString()).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch categories');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error fetching video categories: $e');
    }
  }
} 