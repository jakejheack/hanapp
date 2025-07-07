import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:hanapp/utils/api_config.dart'; // Ensure correct path
import 'package:hanapp/models/doer_job.dart';

class DoerJobService {
  //comment this date 06/07/2025
  // Fetches job listings for a specific Doer, filtered by status
  // Future<Map<String, dynamic>> getDoerJobListings({
  //   required int doerId,
  //   String statusFilter = 'all', // 'all', 'ongoing', 'pending', 'completed', 'cancelled', 'rejected'
  // }) async {
  //   final url = Uri.parse('${ApiConfig.getDoerJobListingsEndpoint}?doer_id=$doerId&status_filter=$statusFilter');
  //   debugPrint('DoerJobService: Fetching Doer jobs from URL: $url');
  //
  //   try {
  //     final response = await http.get(url);
  //     final responseData = json.decode(response.body);
  //
  //     debugPrint('DoerJobService: Get Doer Jobs Status Code: ${response.statusCode}');
  //     debugPrint('DoerJobService: Get Doer Jobs Response Body: ${response.body}');
  //
  //     if (response.statusCode == 200 && responseData['success']) {
  //       List<DoerJob> jobs = (responseData['jobs'] as List)
  //           .map((jobJson) => DoerJob.fromJson(jobJson))
  //           .toList();
  //       return {'success': true, 'jobs': jobs};
  //     } else {
  //       return {'success': false, 'message': responseData['message'] ?? 'Failed to fetch Doer jobs.'};
  //     }
  //   } catch (e) {
  //     debugPrint('DoerJobService: Error fetching Doer jobs: $e');
  //     return {'success': false, 'message': 'Network error: $e'};
  //   }
  // }
  final String _baseUrl = ApiConfig.baseUrl; // Ensure this is your correct backend URL

  Future<Map<String, dynamic>> getDoerJobListings({
    required int doerId,
    String statusFilter = 'all', // Can be 'all', 'pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected'
  }) async {
    // Construct URL for your PHP endpoint
    // Assuming you have a PHP script like 'get_doer_job_listings.php'
    final url = Uri.parse('$_baseUrl/doer_jobs/get_doer_job_listings.php?doer_id=$doerId&status_filter=$statusFilter');

    print('DoerJobService: Fetching Doer jobs from URL: $url');
    print('DoerJobService: doerId: $doerId, statusFilter: $statusFilter');

    try {
      final response = await http.get(url);
      final responseBody = json.decode(response.body);

      print('DoerJobService: Get Doer Job Listings Response: $responseBody');
      print('DoerJobService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200 && responseBody['success']) {
        List<DoerJob> jobs = (responseBody['jobs'] as List)
            .map((jobJson) => DoerJob.fromJson(jobJson as Map<String, dynamic>))
            .toList();
        print('DoerJobService: Parsed ${jobs.length} jobs');
        return {'success': true, 'jobs': jobs};
      } else {
        print('DoerJobService: API call failed - ${responseBody['message']}');
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Failed to load doer job listings. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('DoerJobService: Error fetching doer job listings: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  // Marks an application as complete
  Future<Map<String, dynamic>> markApplicationComplete({
    required int applicationId,
    required int doerId,
    required double earnedAmount,
    String? transactionNo,
  }) async {
    final url = Uri.parse(ApiConfig.markApplicationCompleteEndpoint);
    debugPrint('DoerJobService: Marking application $applicationId complete for doer $doerId with amount $earnedAmount');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'doer_id': doerId,
          'earned_amount': earnedAmount,
          'transaction_no': transactionNo,
        }),
      );
      final responseData = json.decode(response.body);
      debugPrint('DoerJobService: Mark Application Complete Response: $responseData');

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'message': responseData['message']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to mark application complete.'};
      }
    } catch (e) {
      debugPrint('DoerJobService: Error marking application complete: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Cancels an application
  Future<Map<String, dynamic>> cancelApplication({
    required int applicationId,
    required int doerId,
    String? cancellationReason,
  }) async {
    final url = Uri.parse(ApiConfig.cancelApplicationEndpoint);
    debugPrint('DoerJobService: Cancelling application $applicationId for doer $doerId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'application_id': applicationId,
          'doer_id': doerId,
          'cancellation_reason': cancellationReason,
        }),
      );
      final responseData = json.decode(response.body);
      debugPrint('DoerJobService: Cancel Application Response: $responseData');

      if (response.statusCode == 200 && responseData['success']) {
        return {'success': true, 'message': responseData['message']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to cancel application.'};
      }
    } catch (e) {
      debugPrint('DoerJobService: Error cancelling application: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
