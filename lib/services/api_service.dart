import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/models/job_listing.dart'; // Assuming this model exists
import 'package:hanapp/models/applicant.dart'; // Assuming this model exists
import 'package:hanapp/models/doer_profile.dart'; // Assuming this model exists
import 'package:hanapp/utils/api_config.dart'; // Contains your base URL

class ApiService {
  final String _baseUrl = ApiConfig.baseUrl; // From your api_config.dart

  // Fetch job listings by status
  Future<List<JobListing>> fetchListingsByStatus(String status) async {
    final response = await http.get(Uri.parse('$_baseUrl/job_listings.php?status=$status'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['listings'];
      return jsonResponse.map((item) => JobListing.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load listings for status: $status');
    }
  }

  // Delete a listing
  Future<void> deleteListing(String listingId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/delete_listing.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'listing_id': listingId}),
    );

    if (response.statusCode != 200 || !json.decode(response.body)['success']) {
      throw Exception('Failed to delete listing: ${json.decode(response.body)['message']}');
    }
  }

  // Fetch Doer Profile
  Future<DoerProfile> fetchDoerProfile(String doerId) async {
    final response = await http.get(Uri.parse('$_baseUrl/doer_profile.php?doer_id=$doerId'));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body)['profile'];
      return DoerProfile.fromJson(jsonResponse);
    } else {
      throw Exception('Failed to load doer profile: ${json.decode(response.body)['message']}');
    }
  }

  // Fetch applicants for a specific job listing
  Future<List<Applicant>> fetchApplicantsForListing(String listingId) async {
    final response = await http.get(Uri.parse('$_baseUrl/applicants.php?listing_id=$listingId'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['applicants'];
      return jsonResponse.map((item) => Applicant.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load applicants for listing: $listingId');
    }
  }

  // Method to update listing status (e.g., mark as complete, cancel)
  Future<void> updateListingStatus(String listingId, String newStatus) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/update_listing_status.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'listing_id': listingId, 'status': newStatus}),
    );

    if (response.statusCode != 200 || !json.decode(response.body)['success']) {
      throw Exception('Failed to update listing status: ${json.decode(response.body)['message']}');
    }
  }

  // Add a method for posting a new ASAP Listing
  Future<void> postAsapListing(Map<String, dynamic> listingData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/post_asap_listing.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(listingData),
    );

    if (response.statusCode != 200 || !json.decode(response.body)['success']) {
      throw Exception('Failed to post ASAP listing: ${json.decode(response.body)['message']}');
    }
  }
}