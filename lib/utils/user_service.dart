import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/utils/auth_service.dart';

class UserService {
  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    try {
      // Removed token check
      final uri = Uri.parse(ApiConfig.getUserProfileEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      final response = await http.get(uri); // Removed Authorization header
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        return {'success': true, 'user': User.fromJson(responseBody['user'])};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getUserReviews(int reviewedUserId) async {
    try {
      // Removed token check
      final uri = Uri.parse(ApiConfig.getUserReviewsEndpoint).replace(queryParameters: {'reviewed_user_id': reviewedUserId.toString()});
      final response = await http.get(uri); // Removed Authorization header
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        List<Review> reviews = (responseBody['reviews'] as List).map((json) => Review.fromJson(json)).toList();
        return {'success': true, 'reviews': reviews};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Add method to add a user to favorites
  Future<Map<String, dynamic>> addFavorite(int userId, int favoriteUserId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.addFavoriteEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'favorite_user_id': favoriteUserId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Add method to remove a user from favorites
  Future<Map<String, dynamic>> removeFavorite(int userId, int favoriteUserId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.removeFavoriteEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'favorite_user_id': favoriteUserId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Add method to get favorite users
  Future<Map<String, dynamic>> getFavorites(int userId) async {
    try {
      final uri = Uri.parse(ApiConfig.getFavoritesEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        // Assuming the API returns a list of user objects for favorites
        List<User> favorites = (responseBody['favorites'] as List).map((json) => User.fromJson(json)).toList();
        return {'success': true, 'favorites': favorites};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Add method to block a user
  Future<Map<String, dynamic>> blockUser(int userId, int blockedUserId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.blockUserEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'blocked_user_id': blockedUserId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Add method to unblock a user
  Future<Map<String, dynamic>> unblockUser(int userId, int blockedUserId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.unblockUserEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'blocked_user_id': blockedUserId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NEW: Add method to get blocked users
  Future<Map<String, dynamic>> getBlockedUsers(int userId) async {
    try {
      final uri = Uri.parse(ApiConfig.getBlockedUsersEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        // Assuming the API returns a list of user objects for blocked users
        List<User> blockedUsers = (responseBody['blocked_users'] as List).map((json) => User.fromJson(json)).toList();
        return {'success': true, 'blocked_users': blockedUsers};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}