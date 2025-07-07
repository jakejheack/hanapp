import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/verification_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  XFile? _liveFacePhoto;
  bool _isLoading = true; // Set to true initially to show loading state
  final ImagePicker _picker = ImagePicker();
  final VerificationService _verificationService = VerificationService();
  User? _currentUser;
  String? _errorMessage; // For displaying errors during user/status load

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Call async operation in a separate method
  }

  // New method to load user data asynchronously
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService.fetchAndSetUser(); // Ensure latest user data is loaded
      _currentUser = await AuthService.getUser();

      if (_currentUser == null || _currentUser!.id == null) {
        _errorMessage = 'User not logged in. Please log in to verify face.';
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
    } catch (e) {
      debugPrint('FaceVerificationScreen _loadUserData error: $e');
      _errorMessage = 'Error loading user data: ${e.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _captureLiveFacePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 600, maxHeight: 800, imageQuality: 85);

      if (photo != null) {
        final fileSize = await photo.length();
        if (fileSize > 1 * 1024 * 1024) { // 1 MB limit
          _showSnackBar('Image size exceeds 1MB. Please choose a smaller image.', isError: true);
          return;
        }
        setState(() {
          _liveFacePhoto = photo;
        });
      }
    } catch (e) {
      debugPrint('Error capturing live photo: $e');
      _showSnackBar('Failed to capture photo: $e', isError: true);
    }
  }

  Future<void> _submitFaceVerification() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in. Cannot verify face.', isError: true);
      return;
    }
    if (_liveFacePhoto == null) {
      _showSnackBar('Please capture your live face photo.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true; // Use the main isLoading for submission as well
    });

    final response = await _verificationService.requestFaceVerification(
      userId: _currentUser!.id!,
      livePhotoPath: _liveFacePhoto!.path,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message'] ?? 'Face verification successful!');
      if (mounted) {
        Navigator.of(context).pop(); // Navigate back to VerificationScreen
      }
    } else {
      _showSnackBar('Face verification failed: ${response['message']}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face Verification'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face Verification Error'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture Live Face Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector( // Allow tapping the container to capture photo
                onTap: _captureLiveFacePhoto,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(125),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  child: _liveFacePhoto == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.face_retouching_natural, size: 70, color: Colors.grey.shade600),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to capture',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      ),
                      const Text(
                        'Ensure good lighting and centered face.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  )
                      : ClipOval(
                    child: Image.file(
                      File(_liveFacePhoto!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _captureLiveFacePhoto, // Button to also capture
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Capture Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading || _liveFacePhoto == null ? null : _submitFaceVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _liveFacePhoto == null ? Colors.grey : Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Submit for Face Verification',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
