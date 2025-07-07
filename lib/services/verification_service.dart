import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/auth_service.dart';

import '../utils/api_config.dart';

class VerificationService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Submits front and back ID photos for verification.
  Future<Map<String, dynamic>> submitIdVerification({
    required int userId,
    required String idType,
    required String idPhotoFrontPath,
    required String idPhotoBackPath,
    required String brgyClearancePhotoPath, // NEW PARAMETER
    required bool confirmation,
  }) async {
    final url = Uri.parse('$_baseUrl/verification/submit_id_verification.php');
    print('VerificationService: Submitting ID photos to URL: $url');

    try {
      var request = http.MultipartRequest('POST', url)
        ..fields['user_id'] = userId.toString()
        ..fields['id_type'] = idType
        ..fields['confirmation'] = confirmation.toString();

      request.files.add(await http.MultipartFile.fromPath(
        'id_photo_front',
        idPhotoFrontPath,
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'id_photo_back',
        idPhotoBackPath,
      ));
      // NEW: Add Barangay Clearance photo to the request
      request.files.add(await http.MultipartFile.fromPath(
        'brgy_clearance_photo',
        brgyClearancePhotoPath,
      ));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      final decodedResponse = json.decode(responseBody);

      print('VerificationService Submit ID Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        await AuthService.fetchAndSetUser();
        return {'success': true, 'message': decodedResponse['message']};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to submit ID verification.'};
      }
    } catch (e) {
      print('VerificationService Error submitting ID verification: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Submits a live photo for face verification.
  Future<Map<String, dynamic>> requestFaceVerification({
    required int userId,
    required String livePhotoPath,
  }) async {
    final url = Uri.parse('$_baseUrl/verification/request_face_verification.php');
    print('VerificationService: Submitting live photo to URL: $url');

    try {
      var request = http.MultipartRequest('POST', url)
        ..fields['user_id'] = userId.toString();

      request.files.add(await http.MultipartFile.fromPath(
        'live_photo',
        livePhotoPath,
      ));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      final decodedResponse = json.decode(responseBody);

      print('VerificationService Request Face Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        await AuthService.fetchAndSetUser();
        return {'success': true, 'message': decodedResponse['message']};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Face verification failed.'};
      }
    } catch (e) {
      print('VerificationService Error requesting face verification: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Gets the current verification and badge status of a user.
  Future<Map<String, dynamic>> getVerificationStatus({required int userId}) async {
    final url = Uri.parse('$_baseUrl/verification/get_verification_status.php?user_id=$userId');
    print('VerificationService: Getting verification status from URL: $url');

    try {
      final response = await http.get(url);
      final decodedResponse = json.decode(response.body);

      print('VerificationService Get Status Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        final statusData = decodedResponse['status_data'];
        print('VerificationService Raw Status Data: $statusData');
        print('VerificationService verification_status type: ${statusData['verification_status'].runtimeType}');
        print('VerificationService badge_status type: ${statusData['badge_status'].runtimeType}');
        return {'success': true, 'status_data': statusData};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to get verification status.'};
      }
    } catch (e) {
      print('VerificationService Error getting verification status: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Acquires the verified badge for a user (simulates payment/opt-in).
  Future<Map<String, dynamic>> acquireVerifiedBadge({required int userId}) async {
    final url = Uri.parse('$_baseUrl/verification/acquire_badge.php');
    print('VerificationService: Acquiring badge for user: $userId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );
      final decodedResponse = json.decode(response.body);

      print('VerificationService Acquire Badge Response: ${response.statusCode} - $decodedResponse');

      if (response.statusCode == 200 && decodedResponse['success']) {
        await AuthService.fetchAndSetUser(); // Refresh user data after successful badge acquisition
        return {'success': true, 'message': decodedResponse['message']};
      } else {
        return {'success': false, 'message': decodedResponse['message'] ?? 'Failed to acquire badge.'};
      }
    } catch (e) {
      print('VerificationService Error acquiring badge: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
