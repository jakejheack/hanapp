import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/screens/auth/login_screen.dart';
import 'package:hanapp/screens/role_selection_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

import '../../utils/constants.dart' as Constants;
import '../components/custom_button.dart';
import '../../utils/image_utils.dart';
import '../../widgets/date_picker_field.dart';

class SocialCompletionScreen extends StatefulWidget {
  final Map<String, dynamic> socialUserData;
  
  const SocialCompletionScreen({
    super.key,
    required this.socialUserData,
  });

  @override
  State<SocialCompletionScreen> createState() => _SocialCompletionScreenState();
}

class _SocialCompletionScreenState extends State<SocialCompletionScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  // Form keys for validation
  final List<GlobalKey<FormState>> _formKeysForPages = [
    GlobalKey<FormState>(), // Personal Details
    GlobalKey<FormState>(), // Address Details
  ];

  // Controllers for form fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _cityMunicipalityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isQualified = true;

  // Map related variables
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(14.12345, 121.67890);
  Marker? _locationMarker;
  double? _selectedLatitude;
  double? _selectedLongitude;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPageIndex = _pageController.page?.round() ?? 0;
      });
    });

    // Pre-fill data from social login
    _prefillSocialData();
    
    // Pre-fill Country and set Province to Cavite for validation
    _countryController.text = 'Philippines';
    _provinceController.text = 'Cavite';
    _provinceController.addListener(_validateAddress);
    _updateLocationMarker(_selectedLocation);
  }

  void _prefillSocialData() {
    // Extract names from social login data
    String fullName = widget.socialUserData['full_name'] ?? '';

    // Try to get existing name fields first
    String firstName = widget.socialUserData['first_name'] ?? '';
    String middleName = widget.socialUserData['middle_name'] ?? '';
    String lastName = widget.socialUserData['last_name'] ?? '';

    // If individual name fields exist, use them
    if (firstName.isNotEmpty) {
      _firstNameController.text = firstName;
    } else if (fullName.isNotEmpty) {
      // Fall back to parsing full name
      List<String> nameParts = fullName.split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts.first;
      }
    }

    if (middleName.isNotEmpty) {
      _middleNameController.text = middleName;
    } else if (fullName.isNotEmpty) {
      List<String> nameParts = fullName.split(' ');
      if (nameParts.length > 2) {
        _middleNameController.text = nameParts.sublist(1, nameParts.length - 1).join(' ');
      }
    }

    if (lastName.isNotEmpty) {
      _lastNameController.text = lastName;
    } else if (fullName.isNotEmpty) {
      List<String> nameParts = fullName.split(' ');
      if (nameParts.length > 1) {
        _lastNameController.text = nameParts.last;
      }
    }

    // Pre-fill existing data if available
    if (widget.socialUserData['contact_number'] != null && widget.socialUserData['contact_number'].toString().isNotEmpty) {
      _contactNumberController.text = widget.socialUserData['contact_number'].toString();
    }

    if (widget.socialUserData['address_details'] != null && widget.socialUserData['address_details'].toString().isNotEmpty) {
      // Try to parse existing address
      String existingAddress = widget.socialUserData['address_details'].toString();
      List<String> addressParts = existingAddress.split(', ');
      if (addressParts.length >= 5) {
        _streetController.text = addressParts[0];
        _barangayController.text = addressParts[1];
        _cityMunicipalityController.text = addressParts[2];
        _provinceController.text = addressParts[3];
        _countryController.text = addressParts[4];
      }
    }

    if (widget.socialUserData['gender'] != null && widget.socialUserData['gender'].toString().isNotEmpty) {
      _selectedGender = widget.socialUserData['gender'].toString();
    }

    // Role will be selected in the dedicated role selection screen
    // No need to pre-fill role here

    // Handle birthday
    if (widget.socialUserData['birthday'] != null &&
        widget.socialUserData['birthday'].toString() != '1990-01-01') {
      try {
        _selectedDate = DateTime.parse(widget.socialUserData['birthday'].toString());
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      } catch (e) {
        // Fall back to default
        _selectedDate = DateTime(1990, 1, 1);
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }
    } else {
      _selectedDate = DateTime(1990, 1, 1);
      _birthdayController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    }

    // Handle location
    if (widget.socialUserData['latitude'] != null &&
        widget.socialUserData['longitude'] != null &&
        !(widget.socialUserData['latitude'] == 37.4219983 && widget.socialUserData['longitude'] == -122.084)) {
      _selectedLocation = LatLng(
        double.parse(widget.socialUserData['latitude'].toString()),
        double.parse(widget.socialUserData['longitude'].toString())
      );
      _updateLocationMarker(_selectedLocation);
    }
  }

  void _validateAddress() {
    String province = _provinceController.text.toLowerCase();
    setState(() {
      _isQualified = province.contains('cavite');
    });
  }

  void _updateLocationMarker(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedLatitude = location.latitude;
      _selectedLongitude = location.longitude;
      _locationMarker = Marker(
        markerId: const MarkerId('selected_location'),
        position: location,
        infoWindow: const InfoWindow(title: 'Selected Location'),
      );
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _geocodeAddress() async {
    final address = _locationSearchController.text.trim();
    if (address.isEmpty) {
      _showSnackBar('Please enter an address to search.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final latLng = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _selectedLocation = latLng;
          _updateLocationMarker(latLng);
          _selectedLatitude = latLng.latitude;
          _selectedLongitude = latLng.longitude;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15.0));
        _showSnackBar('Location found!');
        _reverseGeocodeLocation(latLng); // Fill individual address fields
      } else {
        _showSnackBar('Address not found. Please try a more specific address.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error searching for address: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocodeLocation(LatLng latLng) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _streetController.text = placemark.street ?? '';
          _barangayController.text = placemark.subLocality ?? placemark.locality ?? '';
          _cityMunicipalityController.text = placemark.locality ?? '';
          _provinceController.text = placemark.administrativeArea == 'Calabarzon' ? 'Cavite' : placemark.administrativeArea ?? '';
          _countryController.text = placemark.country ?? '';
        });
        _validateAddress();
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  bool _validateCurrentPage() {
    if (!_formKeysForPages[_currentPageIndex].currentState!.validate()) {
      return false;
    }

    switch (_currentPageIndex) {
      case 0: // Personal Details
        if (_selectedDate == null) {
          _showSnackBar('Please select your birthday.', isError: true);
          return false;
        }
        break;
      case 1: // Address Details
        if (!_isQualified) {
          _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
          return false;
        }
        if (_streetController.text.isEmpty ||
            _barangayController.text.isEmpty ||
            _cityMunicipalityController.text.isEmpty ||
            _provinceController.text.isEmpty ||
            _countryController.text.isEmpty) {
          _showSnackBar('Please fill all address fields.', isError: true);
          return false;
        }
        if (_contactNumberController.text.isEmpty) {
          _showSnackBar('Please enter your contact number.', isError: true);
          return false;
        }
        break;
    }
    return true;
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPageIndex < 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _completeSocialRegistration();
      }
    }
  }

  void _previousPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSocialRegistration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare address details
      String combinedAddressDetails = '${_streetController.text}, ${_barangayController.text}, '
          '${_cityMunicipalityController.text}, ${_provinceController.text}, ${_countryController.text}';

      // Prepare profile image
      String? base64Image;
      if (_profileImage != null) {
        base64Image = await ImageUtils.fileToBase64(_profileImage!);
      }

      // Complete social registration with all required fields (no role yet)
      final response = await AuthService.completeSocialRegistration(
        socialUserData: widget.socialUserData,
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        birthday: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        addressDetails: combinedAddressDetails,
        gender: _selectedGender!,
        contactNumber: _contactNumberController.text.trim(),
        role: '', // Backend will determine appropriate role
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        profileImageBase64: base64Image,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        _showSnackBar('Profile completed successfully! Please choose your role.');
        // Navigate to role selection screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      } else {
        _showSnackBar(response['message'] ?? 'Profile completion failed', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error completing registration: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: const Color(0xFF141CC9),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (int i = 0; i < 2; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 1 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: i <= _currentPageIndex ? const Color(0xFF141CC9) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                _buildPersonalDetailsPage(),
                _buildAddressDetailsPage(),
              ],
            ),
          ),
          
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPageIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF141CC9),
                        side: const BorderSide(color: Color(0xFF141CC9)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentPageIndex > 0) const SizedBox(width: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141CC9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _currentPageIndex < 1 ? 'Continue' : 'Complete Profile',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildPersonalDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeysForPages[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // Profile Image
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(color: const Color(0xFF141CC9), width: 2),
                  ),
                  child: _profileImage != null
                      ? ClipOval(
                          child: Image.file(
                            _profileImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : widget.socialUserData['profile_picture_url'] != null
                          ? ClipOval(
                              child: Image.network(
                                widget.socialUserData['profile_picture_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF141CC9));
                                },
                              ),
                            )
                          : const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF141CC9)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tap to change profile picture',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _middleNameController,
              decoration: InputDecoration(
                labelText: 'Middle Name (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            DatePickerField(
              controller: _birthdayController,
              labelText: 'Birthday *',
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.wc),
              ),
              items: ['Male', 'Female', 'Other', 'Prefer not to say']
                  .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeysForPages[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Location Search
            TextFormField(
              controller: _locationSearchController,
              decoration: InputDecoration(
                labelText: 'Search Location',
                hintText: 'Enter address or landmark',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _geocodeAddress,
                      ),
              ),
              onFieldSubmitted: (value) => _geocodeAddress(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _streetController,
              decoration: InputDecoration(
                labelText: 'Street Address *',
                hintText: 'e.g., 123 Main Street, Block 1 Lot 2',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.home),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your street address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _barangayController,
              decoration: InputDecoration(
                labelText: 'Barangay *',
                hintText: 'e.g., Barangay San Jose',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_city),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your barangay';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _cityMunicipalityController,
              decoration: InputDecoration(
                labelText: 'City/Municipality *',
                hintText: 'e.g., Dasmariñas City',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_city),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your city/municipality';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _provinceController,
              decoration: InputDecoration(
                labelText: 'Province *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.map),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your province';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _countryController,
              decoration: InputDecoration(
                labelText: 'Country *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.public),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your country';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            if (!_isQualified)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently only available in Cavite. We\'re planning to expand soon!',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Contact Number
            TextFormField(
              controller: _contactNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact Number *',
                hintText: 'e.g., +639123456789',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your contact number';
                }
                if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                  return 'Please enter a valid contact number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Pin Your Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap on the map to set your exact location',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 15,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  onTap: (LatLng location) {
                    _updateLocationMarker(location);
                    _reverseGeocodeLocation(location);
                  },
                  markers: _locationMarker != null ? {_locationMarker!} : {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _birthdayController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _cityMunicipalityController.dispose();
    _provinceController.dispose();
    _countryController.dispose();
    _contactNumberController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }
}
