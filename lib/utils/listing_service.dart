import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/api_config.dart';
import 'package:hanapp/models/listing.dart';
import 'package:hanapp/models/applicant.dart';
import 'package:hanapp/models/review.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/message.dart'; // Import Message model
import 'package:hanapp/models/conversation.dart'; // NEW: Import Conversation model

import '../models/application.dart';
import '../models/message.dart';

class ListingService {
  Future<Map<String, dynamic>> createListing({
    required String listerId,
    required String title,
    required double price,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    String? category,
    String? tags,
    File? imageFile,
    String listingType = 'public', // Default to public
    String? preferredDoerGender,
    double? preferredDoerLocationRadius,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          listingType == 'asap' ? ApiConfig.createAsapListingEndpoint : ApiConfig.createListingEndpoint,
        ),
      );
      request.fields['lister_id'] = listerId;
      request.fields['title'] = title;
      request.fields['price'] = price.toString();
      request.fields['description'] = description;
      request.fields['address'] = address;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['listing_type'] = listingType; // Add listing type

      if (category != null) request.fields['category'] = category;
      if (tags != null) request.fields['tags'] = tags;
      if (preferredDoerGender != null) request.fields['preferred_doer_gender'] = preferredDoerGender;
      if (preferredDoerLocationRadius != null) request.fields['preferred_doer_location_radius'] = preferredDoerLocationRadius.toString();

      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('listing_image', imageFile.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  Future<Map<String, dynamic>> updateListing({
    required int listingId,
    required int listerId, // For authorization on backend
    required String title,
    required String description,
    required String address,
    String? category,
    String? tags,
    File? imageFile, // Optional: for updating image
    String? currentImageUrl, // Optional: to know if image was removed or kept
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.updateListingEndpoint),
      );
      request.fields['listing_id'] = listingId.toString();
      request.fields['lister_id'] = listerId.toString();
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['address'] = address;
      if (category != null) request.fields['category'] = category;
      if (tags != null) request.fields['tags'] = tags;
      if (currentImageUrl != null) request.fields['current_image_url'] = currentImageUrl;


      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('listing_image', imageFile.path));
      } else if (currentImageUrl == null || currentImageUrl.isEmpty) {
        // If no new image is selected and current image was explicitly removed (e.g., by user clearing it)
        request.fields['remove_image'] = 'true';
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getListings({String status = 'active', String? listerId, String? doerId}) async {
    try {
      Map<String, String> queryParams = {'status': status};
      if (listerId != null) queryParams['lister_id'] = listerId;
      if (doerId != null) queryParams['doer_id'] = doerId;

      final uri = Uri.parse(ApiConfig.getListingsEndpoint).replace(queryParameters: queryParams);
      
      // Debug: Print the URL being called
      print('ListingService: Calling getListings with URL: $uri');
      print('ListingService: Query parameters: $queryParams');
      
      final response = await http.get(uri);
      
      // Debug: Print response details
      print('ListingService: Response status code: ${response.statusCode}');
      print('ListingService: Response body: ${response.body}');
      
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      
      if (responseBody['success']) {
        print('ListingService: API returned success: true');
        print('ListingService: Number of listings in response: ${(responseBody['listings'] as List).length}');
        
        try {
          List<Listing> listings = (responseBody['listings'] as List).map((json) {
            print('ListingService: Parsing listing: ${json['id']} - ${json['title']}');
            return Listing.fromJson(json);
          }).toList();
          print('ListingService: Successfully parsed ${listings.length} listings');
          return {'success': true, 'listings': listings};
        } catch (parseError) {
          print('ListingService: Error parsing listings: $parseError');
          return {'success': false, 'message': 'Error parsing listings: $parseError'};
        }
      } else {
        print('ListingService: API returned success: false with message: ${responseBody['message']}');
        return responseBody;
      }
    } catch (e) {
      print('ListingService: Error in getListings: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getListingDetails(int listingId) async {
    try {
      final uri = Uri.parse(ApiConfig.getListingDetailsEndpoint).replace(queryParameters: {'listing_id': listingId.toString()});
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        return {'success': true, 'listing': Listing.fromJson(responseBody['listing'])};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> applyToListing(int listingId, int applicantId, {String? message}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.applyToListingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'listing_id': listingId, 'applicant_id': applicantId ,'message': message}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getApplicants(int listingId) async {
    try {
      final uri = Uri.parse(ApiConfig.getApplicantsEndpoint).replace(queryParameters: {'listing_id': listingId.toString()});
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['success']) {
        List<Applicant> applicants = (responseBody['applicants'] as List).map((json) => Applicant.fromJson(json)).toList();
        return {'success': true, 'applicants': applicants};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteListing(int listingId, int listerId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteListingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'listing_id': listingId, 'lister_id': listerId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> completeListing(int listingId, int listerId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.completeListingEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'listing_id': listingId, 'lister_id': listerId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateApplicationStatus({
    required int applicationId,
    required String status,
    required int initiatorId, // The user ID who is making this status change
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.updateApplicationStatusEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'application_id': applicationId,
          'status': status,
          'initiator_id': initiatorId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  Future<Map<String, dynamic>> submitReview({
    required int reviewerId,
    required int reviewedUserId,
    int? listingId,
    required double rating,
    String? comment,
    List<String>? imagePaths,
    bool saveToFavorites = false,
    bool shareToMyday = false,
    String? mydayCaption,
  }) async {
    try {
      final body = jsonEncode({
        'application_id': listingId,
        'lister_id': reviewerId,
        'doer_id': reviewedUserId,
        'rating': rating,
        'review_content': comment,
        'images': imagePaths ?? [],
        'save_to_favorites': saveToFavorites,
        'share_to_myday': shareToMyday,
        'myday_caption': mydayCaption,
      });
      print('submitReview JSON body: ' + body);
      print('Submitting to: ' + ApiConfig.submitReviewEndpoint);
      final response = await http.post(
        Uri.parse(ApiConfig.submitReviewEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      print('Response status: \\${response.statusCode}');
      print('Response body: \\${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // NEW: Chat and Application Status Methods
  Future<Map<String, dynamic>> sendMessage({
    required int senderId,
    required int receiverId,
    required String messageText,
    int? listingId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendMessageEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'message_text': messageText,
          'listing_id': listingId,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getMessages({
    required int user1Id,
    required int user2Id,
    int? listingId, // Pass listingId to identify the specific conversation
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.getMessagesEndpoint).replace(queryParameters: {
        'user1_id': user1Id.toString(),
        'user2_id': user2Id.toString(),
        if (listingId != null) 'listing_id': listingId.toString(),
      });
      final response = await http.get(uri);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (responseBody['success']) {
        List<Message> messages = (responseBody['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        return {'success': true, 'messages': messages};
      }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  Future<Map<String, dynamic>> getConversations({required int userId}) async {
    try {
      final uri = Uri.parse(ApiConfig.getConversationsEndpoint).replace(queryParameters: {'user_id': userId.toString()});
      final response = await http.get(uri);

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      // if (responseBody['success']) {
      //   List<Conversation> conversations = (responseBody['conversations'] as List)
      //       .map((json) => Conversation.fromJson(json, userId)) // Pass current userId
      //       .toList();
      //   return {'success': true, 'conversations': conversations};
      // }
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // Method to get reviews for a specific user (NEW)
  Future<Map<String, dynamic>> getReviewsForUser(int userId) async {
    final url = Uri.parse('${ApiConfig.getReviewsForUserEndpoint}?reviewed_user_id=$userId');
    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        List<Review> reviews = (responseData['reviews'] as List)
            .map((reviewJson) => Review.fromJson(reviewJson))
            .toList();
        return {'success': true, 'reviews': reviews};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch reviews.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  Future<Map<String, dynamic>> getApplicationDetails(int applicationId) async {
    final url = Uri.parse('${ApiConfig.getApplicationDetailsEndpoint}?application_id=$applicationId');
    try {
      final response = await http.get(url);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'application': Application.fromJson(responseData['application'])};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch application details.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

}