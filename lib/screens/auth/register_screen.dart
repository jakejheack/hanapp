import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/screens/auth/login_screen.dart';
import 'package:hanapp/screens/auth/email_verification_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Import Google Maps
import 'package:geocoding/geocoding.dart'; // Import Geocoding

import '../../utils/constants.dart' as Constants;
import '../components/custom_button.dart';
import '../../utils/image_utils.dart'; // Import ImageUtils

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  final List<GlobalKey<FormState>> _formKeysForPages = List.generate(5, (_) => GlobalKey<FormState>());

  // Controllers for all form fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  DateTime? _selectedDate;

  // Individual address controllers for UI input
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _cityMunicipalityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController(); // For map search

  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _selectedRole; // 'lister' or 'doer'
  String? _selectedGender; // 'Male', 'Female', 'Other', 'Prefer not to say'

  File? _profileImage; // For storing the selected image file
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isQualified = true; // State for qualification based on address (Cavite validation)

  // Map related variables
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(14.12345, 121.67890); // Default to a central point in Cavite, Philippines
  Marker? _locationMarker;
  double? _selectedLatitude;
  double? _selectedLongitude;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPageIndex = _pageController.page?.round() ?? 0;
      });
    });

    // Pre-fill Country and set Province to Cavite for validation
    _countryController.text = 'Philippines';
    _provinceController.text = 'Cavite'; // Pre-fill for validation
    _provinceController.addListener(_validateAddress); // Listen for changes on province
    _updateLocationMarker(_selectedLocation); // Set initial marker
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
    _provinceController.removeListener(_validateAddress);
    _provinceController.dispose();
    _countryController.dispose();
    _locationSearchController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }

  void _validateAddress() {
    final String province = _provinceController.text.trim().toLowerCase();
    setState(() {
      // Only check province for qualification
      _isQualified = (province == 'cavite');
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000), // Default to a reasonable year
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('MMMM d, yyyy').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15.0));
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _updateLocationMarker(latLng);
      _selectedLatitude = latLng.latitude;
      _selectedLongitude = latLng.longitude;
    });
    _reverseGeocodeLocation(latLng); // Update address fields based on map tap
  }

  void _updateLocationMarker(LatLng latLng) {
    setState(() {
      _locationMarker = Marker(
        markerId: const MarkerId('selected_location'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Selected Location'),
      );
    });
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
      List<Location> locations = await geocoding.locationFromAddress(address);
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
      _showSnackBar('Error geocoding address: $e', isError: true);
      debugPrint('Geocoding error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocodeLocation(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        _streetController.text = placemark.street ?? '';
        _barangayController.text = placemark.subLocality ?? placemark.locality ?? ''; // subLocality or locality
        _cityMunicipalityController.text = placemark.locality ?? ''; // locality or subAdministrativeArea
        _provinceController.text = placemark.administrativeArea == 'Calabarzon' ? 'Cavite' : placemark.administrativeArea ?? '';
        _countryController.text = placemark.country ?? '';
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      // Don't show snackbar for reverse geocoding errors, just log
    }
  }

  bool _validateCurrentPage() {
    // Validate the current page's form fields
    if (_formKeysForPages[_currentPageIndex].currentState?.validate() == false) {
      return false;
    }

    // Additional specific validations for each page
    switch (_currentPageIndex) {
      case 0: // Personal Details (Name & Birthday)
        if (_selectedDate == null) {
          _showSnackBar('Please select your birthday.', isError: true);
          return false;
        }
        break;
      case 1: // Address Details (including map location)
        if (!_isQualified) {
          _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
          return false;
        }
        // Ensure all individual address fields are filled
        if (_streetController.text.isEmpty ||
            _barangayController.text.isEmpty ||
            _cityMunicipalityController.text.isEmpty ||
            _provinceController.text.isEmpty ||
            _countryController.text.isEmpty) {
          _showSnackBar('Please fill all address fields.', isError: true);
          return false;
        }
        // Ensure a location is selected on the map
        if (_selectedLatitude == null || _selectedLongitude == null) {
          _showSnackBar('Please select your location on the map or search for it.', isError: true);
          return false;
        }
        break;
      case 2: // Contact & Gender Details
        if (_selectedGender == null) {
          _showSnackBar('Please select your gender.', isError: true);
          return false;
        }
        break;
      case 3: // Account Credentials
      // Password match is handled by validator in TextFormField
        break;
      case 4: // Role Selection (final page)
        if (_selectedRole == null) {
          _showSnackBar('Please select your role (Lister or Doer).', isError: true);
          return false;
        }
        break;
    }
    return true;
  }

  void _goToNextPage() {
    if (_validateCurrentPage()) {
      if (_currentPageIndex < _formKeysForPages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _register() async {
    // Perform a final validation of all fields across all pages
    bool allFieldsValid = true;
    for (int i = 0; i < _formKeysForPages.length; i++) {
      if (_formKeysForPages[i].currentState?.validate() == false) {
        allFieldsValid = false;
        _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
        _showSnackBar('Please fill all required fields correctly.', isError: true);
        return;
      }
    }

    if (!_isQualified) {
      _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeIn); // Go to address page
      return;
    }
    if (_selectedRole == null) {
      _showSnackBar('Please select your role (Lister or Doer).', isError: true);
      _pageController.animateToPage(4, duration: const Duration(milliseconds: 300), curve: Curves.easeIn); // Go to role page
      return;
    }
    if (_selectedGender == null) {
      _showSnackBar('Please select your gender.', isError: true);
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeIn); // Go to gender page
      return;
    }
    if (_selectedDate == null) {
      _showSnackBar('Please select your birthday.', isError: true);
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeIn); // Go to personal page
      return;
    }
    if (_selectedLatitude == null || _selectedLongitude == null) {
      _showSnackBar('Please select your location on the map or search for it.', isError: true);
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeIn); // Go to address page
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Combine individual address fields into a single string for addressDetails
    final String combinedAddressDetails = [
      _streetController.text.trim(),
      _barangayController.text.trim(),
      _cityMunicipalityController.text.trim(),
      _provinceController.text.trim(),
      _countryController.text.trim(),
    ].where((s) => s.isNotEmpty).join(', '); // Join non-empty parts with a comma and space

    // Convert _profileImage to base64
    String? base64Image;
    if (_profileImage != null) {
      base64Image = await ImageUtils.fileToBase64(_profileImage!);
    }

    final response = await AuthService.register(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      birthday: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      addressDetails: combinedAddressDetails, // Pass the combined string for display
      gender: _selectedGender!,
      contactNumber: _contactNumberController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole!,
      latitude: _selectedLatitude,   // Pass latitude to backend
      longitude: _selectedLongitude, // Pass longitude to backend
      profileImageBase64: base64Image, // Pass base64 encoded image to backend
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message']);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(email: _emailController.text.trim()),
        ),
      );
    } else {
      _showSnackBar('Registration failed: ${response['message']}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: const Color(0xFF141CC9),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Linear progress indicator for pages
          LinearProgressIndicator(
            value: (_currentPageIndex + 1) / _formKeysForPages.length,
            backgroundColor: Colors.grey.shade300,
            color: const Color(0xFF141CC9),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable manual swiping
              children: [
                // Page 1: Profile Picture, Name Fields, Birthday
                _buildPersonalDetailsPage(),
                // Page 2: Address Details (now with individual fields and map)
                _buildAddressDetailsPage(),
                // Page 3: Gender & Contact Number
                _buildContactGenderDetailsPage(),
                // Page 4: Email & Password
                _buildAccountCredentialsPage(),
                // Page 5: Role Selection & Register
                _buildRoleSelectionPage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPageIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goToPreviousPage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF141CC9),
                        side: const BorderSide(color: Color(0xFF141CC9)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentPageIndex > 0 && _currentPageIndex < _formKeysForPages.length - 1)
                  const SizedBox(width: 16),
                if (_currentPageIndex < _formKeysForPages.length - 1)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141CC9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                if (_currentPageIndex == _formKeysForPages.length - 1)
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141CC9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeysForPages[0], // Unique key for this page's form
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Your Account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF141CC9)),
            ),
            const SizedBox(height: 24),

            // Profile Picture Upload Section
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _profileImage != null 
                        ? FileImage(_profileImage!) 
                        : null,
                    child: _profileImage == null
                        ? Icon(
                      Icons.camera_alt,
                      size: 50,
                      color: Colors.grey.shade600,
                    )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141CC9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.add_a_photo,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _pickImage,
              child: const Text('Upload your profile picture'),
            ),
            const SizedBox(height: 24),

            // Name Fields
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name',
                hintText: 'Enter your first name',
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
                hintText: 'Enter your middle name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name',
                hintText: 'Enter your last name',
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

            // Birthday Field
            TextFormField(
              controller: _birthdayController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: InputDecoration(
                labelText: 'Birthday',
                hintText: 'Select your birthday',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              validator: (value) {
                if (_selectedDate == null) {
                  return 'Please select your birthday';
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
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeysForPages[1], // Unique key for this page's form
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Where do you live?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Map Section
            Container(
              height: 250, // Fixed height for the map
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 15.0,
                  ),
                  markers: _locationMarker != null ? {_locationMarker!} : {},
                  onTap: _onMapTap,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
              onFieldSubmitted: (value) => _geocodeAddress(), // Trigger on Enter
            ),
            const SizedBox(height: 24),
            Text(
              'Selected Coordinates: Lat: ${_selectedLatitude?.toStringAsFixed(5) ?? 'N/A'}, Long: ${_selectedLongitude?.toStringAsFixed(5) ?? 'N/A'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            // Individual Address Fields
            TextFormField(
              controller: _streetController,
              decoration: InputDecoration(
                labelText: 'Street',
                hintText: 'Enter your street address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_on),
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
                labelText: 'Barangay',
                hintText: 'Enter your barangay',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_on),
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
                labelText: 'City/Municipality',
                hintText: 'Enter your city/municipality',
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
                labelText: 'Province',
                hintText: 'Enter your province (e.g., Cavite)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.area_chart),
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
                labelText: 'Country',
                hintText: 'Enter your country',
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
            const SizedBox(height: 24),
            // Qualification Message
            if (!_isQualified)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Sorry, it's currently unavailable in your area. We're planning to expand soon.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactGenderDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeysForPages[2], // Unique key for this page's form
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Contact & Gender Details:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              hint: const Text('Select Gender'),
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.people),
              ),
              items: <String>['Male', 'Female', 'Other', 'Prefer not to say']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact Number',
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
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCredentialsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeysForPages[3], // Unique key for this page's form
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set up your account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_confirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _confirmPasswordVisible = !_confirmPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(BuildContext context, String title, IconData icon, String roleValue, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRole = roleValue;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF141CC9) : Colors.blue.shade50, // Selected color vs. light blue
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF141CC9) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: const Color(0xFF141CC9).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 50,
                color: isSelected ? Colors.white : const Color(0xFF141CC9),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '(${roleValue == 'lister' ? 'Post Jobs' : 'Find Jobs'})',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeysForPages[4], // Unique key for this page's form
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
          children: [
            const Text(
              'Choose Your Role',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Don\'t worry, you can switch roles inside',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoleOption(
                    context,
                    'Lister',
                    Icons.edit, // Icon for Lister (e.g., pencil)
                    'lister',
                    _selectedRole == 'lister',
                  ),
                  const SizedBox(width: 20), // Space between buttons
                  _buildRoleOption(
                    context,
                    'Doer',
                    Icons.build, // Icon for Doer (e.g., hammer)
                    'doer',
                    _selectedRole == 'doer',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Already have an account? Login
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: Text(
                'Already have an account? Login',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 24), // Space before social logins
          ],
        ),
      ),
    );
  }
}
