import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File
import 'package:hanapp/utils/constants.dart' as Constants;

// This screen is a generic screen to capture a photo using the device's camera
// and return the XFile object. It can be reused for ID photos or live face photos.

class LivePhotoCaptureScreen extends StatefulWidget {
  const LivePhotoCaptureScreen({super.key});

  @override
  State<LivePhotoCaptureScreen> createState() => _LivePhotoCaptureScreenState();
}

class _LivePhotoCaptureScreenState extends State<LivePhotoCaptureScreen> {
  XFile? _capturedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    // Automatically launch camera on init, or provide a button
    _capturePhoto();
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _isCapturing = true;
    });
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800, // Optimize image size for upload
        maxHeight: 600,
        imageQuality: 90, // Adjust quality if file size is an issue
      );

      setState(() {
        _capturedImage = photo;
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      _showSnackBar('Failed to capture photo: ${e.toString()}', isError: true);
      setState(() {
        _isCapturing = false;
      });
      // Pop if camera fails to initialize or user cancels immediately
      if (mounted && _capturedImage == null) {
        Navigator.of(context).pop();
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Photo'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isCapturing
          ? const Center(child: CircularProgressIndicator())
          : _capturedImage == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No photo captured. Please try again.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _capturePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retake Photo'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain, // Adjust to cover or contain
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        _capturePhoto(); // Retake
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Retake',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(_capturedImage); // Return the captured image
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4), // Blue color to match modal
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Use Photo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
