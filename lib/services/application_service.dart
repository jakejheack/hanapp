import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/applicantv2.dart';
import 'package:hanapp/models/public_listing.dart';
import 'package:hanapp/models/application.dart';

import '../utils/api_config.dart';

class ApplicationService {
  final String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> createApplication({
    required int listingId,
    required String listingType,
    required int listerId,
    required int doerId,
    required String message,
    required String listingTitle,
  }) async {
    final url = Uri.parse('$_baseUrl/applications/create_application.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'listing_id': listingId,
          'listing_type': listingType,
          'lister_id': listerId,
          'doer_id': doerId,
          'message': message,
          'listing_title': listingTitle,
        }),
      );

      final responseBody = json.decode(response.body);
      print('ApplicationService Create Application Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message'], 'application_id': responseBody['application_id']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to apply for job.'};
      }
    } catch (e) {
      print('ApplicationService Error creating application: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getApplicationDetails({required int applicationId}) async {
    final url = Uri.parse('$_baseUrl/applications/get_application_details.php?application_id=$applicationId');
    print('ApplicationService: Fetching application details from URL: $url');

    try {
      final response = await http.get(url);
      print('ApplicationService: Received status code (getApplicationDetails): ${response.statusCode}');
      print('ApplicationService: RAW RESPONSE BODY (getApplicationDetails): ${response.body}');

      if (response.body.isEmpty) {
        print('ApplicationService: Received empty response body for getApplicationDetails.');
        return {'success': false, 'message': 'Empty response from server for application details.'};
      }

      final responseBody = json.decode(response.body);
      print('ApplicationService: Decoded JSON response (getApplicationDetails): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'application': Application.fromJson(responseBody['application'])};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to load application details.'};
      }
    } catch (e) {
      print('ApplicationService Error fetching application details: $e');
      return {'success': false, 'message': 'Network error: $e. Please check server logs.'};
    }
  }

  /// Updates the status of a job application.
  Future<Map<String, dynamic>> updateApplicationStatus({
    required int applicationId,
    required String newStatus,
    required int currentUserId, // The user making the request (Lister or Doer)
  }) async {
    final url = Uri.parse('$_baseUrl/applications/update_application_status.php');
    print('ApplicationService: Updating application status for ID: $applicationId to $newStatus by user: $currentUserId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'new_status': newStatus,
          'current_user_id': currentUserId,
        }),
      );

      final responseBody = json.decode(response.body);
      print('ApplicationService Update Status Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to update application status.'};
      }
    } catch (e) {
      print('ApplicationService Error updating status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getListingApplicants(int listingId, String listingType) async {
    final url = Uri.parse('$_baseUrl/applications/get_listing_applicants.php?listing_id=$listingId&listing_type=$listingType');
    print('ApplicationService: Fetching applicants from URL: $url');

    try {
      final response = await http.get(url);
      print('ApplicationService: Received status code (getListingApplicants): ${response.statusCode}');
      print('ApplicationService: RAW RESPONSE BODY (getListingApplicants): ${response.body}');

      if (response.body.isEmpty) {
        print('ApplicationService: Received empty response body for getListingApplicants. Returning failure.');
        return {'success': false, 'message': 'Empty response from server for applicants. Check server logs.'};
      }

      final responseBody = json.decode(response.body);
      print('ApplicationService: Decoded JSON response (getListingApplicants): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        final List<dynamic> rawApplicants = responseBody['applicants'] as List;
        print('ApplicationService: Number of raw applicants received: ${rawApplicants.length}');

        List<Applicant> applicants = rawApplicants
            .map((applicantJson) {
          try {
            print('ApplicationService: Attempting to parse applicant JSON: $applicantJson');
            return Applicant.fromJson(applicantJson as Map<String, dynamic>);
          } catch (e) {
            print('ApplicationService: ERROR parsing single applicant: $applicantJson. Error: $e');
            rethrow;
          }
        })
            .toList();
        return {'success': true, 'applicants': applicants};
      } else {
        print('ApplicationService: Server returned success: false or unexpected status for getListingApplicants: ${responseBody['message']}');
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to fetch applicants.'};
      }
    } catch (e) {
      print('ApplicationService Error fetching applicants: $e. This likely means invalid JSON or network issue.');
      return {'success': false, 'message': 'Network error: $e. Please check server logs (Apache/PHP error logs).'};
    }
  }

  /// Method to get applications for a specific Doer
  Future<Map<String, dynamic>> getApplicationsForDoer({required int doerId}) async {
    final url = Uri.parse('$_baseUrl/applications/get_applications_for_doer.php?doer_id=$doerId');
    print('ApplicationService: Fetching applications for Doer ID: $doerId from URL: $url');

    try {
      final response = await http.get(url);
      print('ApplicationService: Received status code (getApplicationsForDoer): ${response.statusCode}');
      print('ApplicationService: RAW RESPONSE BODY (getApplicationsForDoer): ${response.body}');

      if (response.body.isEmpty) {
        print('ApplicationService: Received empty response body for getApplicationsForDoer. Returning failure.');
        return {'success': false, 'message': 'Empty response from server for doer applications.'};
      }

      final responseBody = json.decode(response.body);
      print('ApplicationService: Decoded JSON response (getApplicationsForDoer): $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        List<Application> applications = (responseBody['applications'] as List)
            .map((appJson) {
          try {
            print('ApplicationService: Attempting to parse application JSON for Doer: $appJson');
            return Application.fromJson(appJson as Map<String, dynamic>);
          } catch (e) {
            print('ApplicationService: ERROR parsing single Doer application: $appJson. Error: $e');
            rethrow; // Re-throw to propagate the error
          }
        })
            .toList();
        return {'success': true, 'applications': applications};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to fetch doer applications.'};
      }
    } catch (e) {
      print('ApplicationService Error fetching doer applications: $e');
      return {'success': false, 'message': 'Network error fetching doer applications: $e'};
    }
  }
  /// Mark a job application as complete (for Lister).
  Future<Map<String, dynamic>> markJobAsComplete({
    required int applicationId,
    required int listerId,
    required int doerId,
    required String listingTitle,
  }) async {
    final url = Uri.parse('$_baseUrl/applications/mark_job_complete.php');
    print('ChatService: Marking job complete for application ID: $applicationId by Lister: $listerId with Doer: $doerId. Title: $listingTitle');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'lister_id': listerId,
          'doer_id': doerId,
          'listing_title': listingTitle,
        }),
      );

      final responseBody = json.decode(response.body);
      print('ChatService Mark Job Complete Response: $responseBody');

      if (response.statusCode == 200 && responseBody['success']) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to mark job complete.'};
      }
    } catch (e) {
      print('ChatService Error marking job complete: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
