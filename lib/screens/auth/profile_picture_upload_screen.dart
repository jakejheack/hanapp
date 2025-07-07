import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/image_utils.dart';

class ProfilePictureUploadScreen extends StatefulWidget {
  const ProfilePictureUploadScreen({super.key});

  @override
  State<ProfilePictureUploadScreen> createState() => _ProfilePictureUploadScreenState();
}

class _ProfilePictureUploadScreenState extends State<ProfilePictureUploadScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      // Handle case where user is not logged in
      Navigator.of(context).pushReplacementNamed('/login');
    }
    setState(() {}); // Refresh UI with user data
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) {
      _showSnackBar('Please select a profile picture first.', isError: true);
      return;
    }
    if (_currentUser == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Convert File to XFile for upload
    final xFile = XFile(_imageFile!.path);
    final response = await _authService.uploadProfilePicture(
      _currentUser!.id.toString(), // Convert user ID to string
      xFile,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message']);
      // Update local user object with new profile picture URL
      if (_currentUser != null && response['url'] != null) {
        _currentUser = _currentUser!.copyWith(profilePictureUrl: response['url']);
        await AuthService.saveUser(_currentUser!);
        print('🔧 Updated local user with new profile picture URL: ${response['url']}');
      }
      Navigator.of(context).pushReplacementNamed('/role_selection');
    } else {
      _showSnackBar(response['message'], isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upload Profile Picture'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : ImageUtils.createProfileImageProvider(_currentUser!.profilePictureUrl),
                child: _imageFile == null && (_currentUser!.profilePictureUrl == null || _currentUser!.profilePictureUrl!.isEmpty)
                    ? Icon(
                  Icons.camera_alt,
                  size: 60,
                  color: Colors.grey[600],
                )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload your profile picture',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
              text: 'Get Started',
              onPressed: _uploadProfilePicture,
            ),
          ],
        ),
      ),
    );
  }
}