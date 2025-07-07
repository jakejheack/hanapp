import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/screens/select_location_on_map_screen.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:geocoding/geocoding.dart' as geocoding; // Import for geocoding
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  XFile? _pickedXFile;
  final ImagePicker _picker = ImagePicker();
  User? _currentUser;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  String? _mapSelectedAddress; // Stores the address string that came from map selection

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndPopulateFields();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndPopulateFields() async {
    setState(() {
      _isLoading = true;
    });
    
    // First try to get user from local storage
    _currentUser = await AuthService.getUser();
    
    // If user exists, force refresh from database to get latest data
    if (_currentUser != null) {
      await _refreshUserFromDatabase();
    } else {
      // If no user in local storage, try to refresh
      await AuthService.refreshUser();
      _currentUser = await AuthService.getUser();
      if (_currentUser == null && mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
    }

    if (_currentUser != null) {
      // Debug prints to see what data is available
      print('🔍 Edit Profile - Loading user data:');
      print('🔍 Full Name: ${_currentUser!.fullName}');
      print('🔍 Email: ${_currentUser!.email}');
      print('🔍 Contact Number: ${_currentUser!.contactNumber}');
      print('🔍 Address Details: ${_currentUser!.addressDetails}');
      print('🔍 Latitude: ${_currentUser!.latitude}');
      print('🔍 Longitude: ${_currentUser!.longitude}');
      
      _fullNameController.text = _currentUser!.fullName;
      _emailController.text = _currentUser!.email;
      _contactNumberController.text = _currentUser!.contactNumber ?? '';
      _addressController.text = _currentUser!.addressDetails ?? '';
      _latitude = _currentUser!.latitude;
      _longitude = _currentUser!.longitude;
      _mapSelectedAddress = _currentUser!.addressDetails; // Initial address is from DB
      
      // Debug prints after setting controller values
      print('🔍 After setting controller values:');
      print('🔍 Full Name Controller: ${_fullNameController.text}');
      print('🔍 Email Controller: ${_emailController.text}');
      print('🔍 Contact Number Controller: ${_contactNumberController.text}');
      print('🔍 Address Controller: ${_addressController.text}');
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshUserFromDatabase() async {
    try {
      // Get user ID from local storage
      final prefs = await SharedPreferences.getInstance();
      final String? userIdStr = prefs.getString('user_id');
      
      if (userIdStr != null) {
        final int userId = int.parse(userIdStr);
        
        // Fetch fresh user data from database
        final response = await AuthService().getUserProfileById(userId: userId);
        
        if (response['success'] && response['user'] != null) {
          // Create new user object with fresh data
          final freshUser = User.fromJson(response['user']);
          
          // Save to local storage
          await AuthService.saveUser(freshUser);
          
          // Update current user
          _currentUser = freshUser;
          
          print('🔍 Successfully refreshed user data from database');
        } else {
          print('🔍 Failed to refresh user data: ${response['message']}');
        }
      }
    } catch (e) {
      print('🔍 Error refreshing user data: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    // SnackBar removed as per user request. No action needed.
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Compare the picked file path with the current profile picture URL (if local file)
      // If the current profile picture is a network URL, compare the file name
      bool isSameImage = false;
      if (_currentUser != null && _currentUser!.profilePictureUrl != null && _currentUser!.profilePictureUrl!.isNotEmpty) {
        final currentPicUrl = _currentUser!.profilePictureUrl!;
        // If the current profile picture is a file path
        if (currentPicUrl.startsWith('file://')) {
          isSameImage = pickedFile.path == currentPicUrl.replaceFirst('file://', '');
        } else {
          // Compare file names if possible
          final pickedFileName = pickedFile.path.split('/').last;
          final currentFileName = currentPicUrl.split('/').last;
          isSameImage = pickedFileName == currentFileName;
        }
      }
      if (isSameImage) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              title: const Text('Same Image Selected'),
              content: const Text('You selected the same profile picture. Please choose a different image if you want to update your profile picture.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
      setState(() {
        _pickedXFile = pickedFile;
      });
    }
  }

  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SelectLocationOnMapScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _addressController.text,
        ),
      ),
    ) as Map<String, dynamic>?;

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _addressController.text = result['address'];
        _mapSelectedAddress = result['address']; // Store the map-selected address
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_currentUser == null || _currentUser!.id == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // If the profile image is unchanged, show a confirmation dialog
    if (_pickedXFile == null) {
      final bool? continueUpdate = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Profile Picture Not Changed'),
            content: const Text("You didn't change your profile picture, continue updating your profile?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          );
        },
      );
      if (continueUpdate != true) {
        return;
      }
    }

    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _contactNumberController.text.isEmpty ||
        _addressController.text.isEmpty) {
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // --- Geocoding Logic for Manual Address Input ---
    // If address has been manually changed OR lat/lng are null but address is not empty
    if (_addressController.text.isNotEmpty && (_latitude == null || _longitude == null || _addressController.text != _mapSelectedAddress)) {
      try {
        List<geocoding.Location> locations = await geocoding.locationFromAddress(_addressController.text);
        if (locations.isNotEmpty) {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
          _mapSelectedAddress = _addressController.text; // Treat as if map selected for future checks
        } else {
          // Address not found or ambiguous
          await _showAddressGeocodingWarningDialog();
          if (_latitude == null || _longitude == null) { // User chose to cancel or proceed without coordinates
            setState(() { _isLoading = false; });
            return; // Stop saving if user cancelled or explicitly chose not to proceed without coords
          }
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
        await _showAddressGeocodingWarningDialog(error: e.toString());
        if (_latitude == null || _longitude == null) {
          setState(() { _isLoading = false; });
          return;
        }
      }
    } else if (_addressController.text.isEmpty && (_latitude != null || _longitude != null)) {
      // If address is cleared, but lat/lng are still present, nullify them
      _latitude = null;
      _longitude = null;
      _mapSelectedAddress = null;
    }

    // After geocoding (or if it was not needed/failed and user proceeded)
    // Check if coordinates are still required and missing
    if (_addressController.text.isNotEmpty && (_latitude == null || _longitude == null)) {
      setState(() { _isLoading = false; });
      return;
    }


    try {
      // Handle profile picture upload separately if image was selected
      if (_pickedXFile != null) {
        final uploadResponse = await AuthService().uploadProfilePicture(
          _currentUser!.id.toString(),
          _pickedXFile!,
        );
        
        if (!uploadResponse['success']) {
          throw Exception(uploadResponse['message'] ?? 'Failed to upload profile picture');
        }
        
        // Update local user data with new profile picture URL
        if (uploadResponse['url'] != null && _currentUser != null) {
          _currentUser = _currentUser!.copyWith(profilePictureUrl: uploadResponse['url']);
          await AuthService.saveUser(_currentUser!);
          print('🔧 Updated local user with new profile picture URL: ${uploadResponse['url']}');
        }
      }

      final response = await AuthService.updateUserProfile(
        userId: _currentUser!.id,
        fullName: _fullNameController.text,
        email: _emailController.text,
        contactNumber: _contactNumberController.text,
        addressDetails: _addressController.text,
        latitude: _latitude, // Now potentially updated by geocoding
        longitude: _longitude, // Now potentially updated by geocoding
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        await AuthService.refreshUser();
        if (mounted) {
          _loadCurrentUserAndPopulateFields(); // Re-populate to reflect potential new profile pic URL
          Navigator.of(context).pop();
        }
      } else {
        setState(() { _isLoading = false; });
        // Error message already handled in catch block
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error updating profile: $e');
    }
  }

  // Dialog for when geocoding fails or address is ambiguous
  Future<void> _showAddressGeocodingWarningDialog({String? error}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Address Warning'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'The address you entered could not be precisely located or is ambiguous. '
                      'The app relies on coordinates for some features.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                Text(
                  'What would you like to do?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Select on Map Instead'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                _selectLocationOnMap(); // Re-open map to force selection
              },
            ),
            TextButton(
              child: const Text('Proceed Without Exact Location'),
              onPressed: () {
                // User chooses to proceed without exact lat/lng for now
                _latitude = null; // Ensure lat/lng are null if user proceeds without
                _longitude = null;
                _mapSelectedAddress = null; // Invalidate map address
                Navigator.of(dialogContext).pop(); // Close dialog
                _saveChanges(); // Retry saving
              },
            ),
            TextButton(
              child: const Text('Cancel Save'),
              onPressed: () {
                _latitude = null; // Ensure lat/lng are null
                _longitude = null;
                _mapSelectedAddress = null; // Invalidate map address
                Navigator.of(dialogContext).pop(); // Close dialog
                // No further action, user will remain on edit screen to correct address
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    ImageProvider<Object>? imageProvider = ImageUtils.getProfileImageProvider(
      selectedFile: _pickedXFile,
      storedImageUrl: _currentUser!.profilePictureUrl,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _refreshUserFromDatabase();
              if (_currentUser != null) {
                _fullNameController.text = _currentUser!.fullName;
                _emailController.text = _currentUser!.email;
                _contactNumberController.text = _currentUser!.contactNumber ?? '';
                _addressController.text = _currentUser!.addressDetails ?? '';
                _latitude = _currentUser!.latitude;
                _longitude = _currentUser!.longitude;
                _mapSelectedAddress = _currentUser!.addressDetails;
              }
              setState(() {
                _isLoading = false;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: imageProvider,
                child: (_pickedXFile == null && (_currentUser!.profilePictureUrl == null || _currentUser!.profilePictureUrl!.isEmpty))
                    ? Icon(
                  Icons.camera_alt,
                  size: 40,
                  color: Colors.grey[600],
                )
                    : null,
                onBackgroundImageError: imageProvider != null ? (exception, stackTrace) {
                  print('Edit Profile: Error loading profile image: $exception');
                  // Don't call setState during build - just log the error
                } : null,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                prefixIcon: Icon(Icons.person),
              ),
              // No validator here, as _saveChanges handles validation directly before API call
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              // No validator here
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNumberController,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              // readOnly is removed here to allow manual input
              decoration: InputDecoration(
                labelText: 'Address', // Changed label from 'Saved Address'
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: _selectLocationOnMap,
                ),
              ),
              onChanged: (text) {
                // If the user manually changes the address, invalidate current lat/lng
                // so it's re-geocoded or requires map selection on save.
                if (text != _mapSelectedAddress) {
                  setState(() {
                    _latitude = null;
                    _longitude = null;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Save Changes',
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
