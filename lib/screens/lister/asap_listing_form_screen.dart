import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hanapp/utils/asap_listing_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/word_filter_service.dart';
import 'package:hanapp/widgets/banned_words_dialog.dart';
import 'dart:math' as math;

import '../components/custom_button.dart';

class AsapListingFormScreen extends StatefulWidget {
  const AsapListingFormScreen({super.key});

  @override
  State<AsapListingFormScreen> createState() => _AsapListingFormScreenState();
}

class _AsapListingFormScreenState extends State<AsapListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(14.4167, 120.9333); // Center of Cavite
  Marker? _locationMarker;
  double? _listingLatitude;
  double? _listingLongitude;

  // Cavite province geographical bounds
  static final LatLngBounds _caviteBounds = LatLngBounds(
    southwest: const LatLng(14.1000, 120.6000), // Southwest corner of Cavite
    northeast: const LatLng(14.7000, 121.2000), // Northeast corner of Cavite
  );

  String? _preferredDoerGender;
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  String? _selectedPaymentMethod;
  String? _selectedBank; // For bank transfer selection

  // Fees (fixed doer fee)
  double _doerFee = 25.0;
  double _transactionFee = 0.0;
  double _totalAmount = 25.0;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateFees();
  }

  // Check if a location is within Cavite province bounds
  bool _isLocationInCavite(LatLng location) {
    return location.latitude >= _caviteBounds.southwest.latitude &&
           location.latitude <= _caviteBounds.northeast.latitude &&
           location.longitude >= _caviteBounds.southwest.longitude &&
           location.longitude <= _caviteBounds.northeast.longitude;
  }

  // Check if an address contains Cavite-related keywords (same logic as sign-up)
  bool _isAddressInCavite(String address) {
    final caviteKeywords = [
      'cavite', 'imus', 'dasmarinas', 'bacoor', 'general trias', 'kawit',
      'noveleta', 'rosario', 'tanza', 'naic', 'ternate', 'maragondon',
      'magallanes', 'alfonso', 'mendez', 'tagaytay', 'indang', 'silang',
      'amadeo', 'general emilio aguinaldo', 'carmona'
    ];

    final lowerAddress = address.toLowerCase();
    return caviteKeywords.any((keyword) => lowerAddress.contains(keyword));
  }

  // Validate location using reverse geocoding (same as sign-up logic)
  Future<bool> _validateLocationByCaviteProvince(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];
        // Same logic as sign-up: check if administrativeArea is Cavite or Calabarzon
        final province = placemark.administrativeArea?.toLowerCase() ?? '';

        // Match sign-up logic: Calabarzon region maps to Cavite
        bool isQualified = (province == 'cavite') ||
                          (province == 'calabarzon') ||
                          (placemark.administrativeArea == 'Calabarzon');

        print('🔍 Location validation: Province = ${placemark.administrativeArea}, Qualified = $isQualified');
        return isQualified;
      }

      return false;
    } catch (e) {
      print('❌ Error validating location: $e');
      return false;
    }
  }

  // Custom input formatter for Philippine peso amounts
  static final RegExp _pesoRegex = RegExp(r'^\d*\.?\d{0,2}$');

  List<TextInputFormatter> get _pesoInputFormatters => [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    TextInputFormatter.withFunction((oldValue, newValue) {
      // Allow empty string
      if (newValue.text.isEmpty) {
        return newValue;
      }

      // Check if the new value matches our peso format
      if (_pesoRegex.hasMatch(newValue.text)) {
        // Ensure only one decimal point
        if (newValue.text.split('.').length <= 2) {
          return newValue;
        }
      }

      // If invalid, keep the old value
      return oldValue;
    }),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationSearchController.dispose();
    _locationAddressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 6,
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
      // First check if the address contains Cavite keywords
      if (!_isAddressInCavite(address)) {
        _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<geocoding.Location> locations = await geocoding.locationFromAddress(address + ', Cavite, Philippines');
      if (locations.isNotEmpty) {
        geocoding.Location location = locations.first;
        LatLng latLng = LatLng(location.latitude, location.longitude);

        // Validate using the same logic as sign-up
        bool isValidCaviteLocation = await _validateLocationByCaviteProvince(latLng);
        if (!isValidCaviteLocation) {
          _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
          setState(() {
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _selectedLocation = latLng;
          _updateLocationMarker(latLng);
          _listingLatitude = latLng.latitude;
          _listingLongitude = latLng.longitude;
          // Set the searched address immediately
          _locationAddressController.text = address;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.0));
        _showSnackBar('🔍 Location found! Tap the map to fine-tune if needed.');

        // Also try to get a more detailed address via reverse geocoding
        _reverseGeocodeLocation(latLng);
      } else {
        _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
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

  void _calculateFees() {
    double price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _doerFee = 25.0;
      _transactionFee = 0.0;
      _totalAmount = price + _doerFee;
    });
  }

  Future<void> _createAsapListing() async {
    print('🔍 Starting form validation...');

    if (_formKey.currentState!.validate()) {
      print('✅ Basic form validation passed');

      final price = double.tryParse(_priceController.text);
      print('💰 Price validation: ${_priceController.text} -> $price');
      if (price == null || price < 500) {
        print('❌ Price validation failed');
        _showSnackBar('❌ Doer Fee must be at least Php 500. Please check the Doer Fee field.', isError: true);
        return;
      }

      print('📍 Location validation: lat=$_listingLatitude, lng=$_listingLongitude, address=${_locationAddressController.text}');
      if (_listingLatitude == null || _listingLongitude == null || _locationAddressController.text.isEmpty) {
        print('❌ Location validation failed');
        _showSnackBar('📍 Please select a location on the map. Tap on the map to choose your location.', isError: true);
        return;
      }

      print('👤 Preferred doer validation: $_preferredDoerGender');
      if (_preferredDoerGender == null) {
        print('❌ Preferred doer validation failed');
        _showSnackBar('👤 Please select a preferred doer (Any, Male, or Female) in the Preferred Doer field.', isError: true);
        return;
      }

      print('💳 Payment method validation: $_selectedPaymentMethod');
      if (_selectedPaymentMethod == null) {
        print('❌ Payment method validation failed');
        _showSnackBar('💳 Please select a payment method from the Payment Methods section.', isError: true);
        return;
      }

      // Validate bank selection if Bank Transfer is selected
      if (_selectedPaymentMethod == 'Bank Transfer' && _selectedBank == null) {
        print('❌ Bank selection validation failed');
        _showSnackBar('🏦 Please select a bank for Bank Transfer payment method.', isError: true);
        return;
      }

      print('✅ All validations passed, proceeding with listing creation...');
    } else {
      print('❌ Basic form validation failed');
      _showSnackBar('❌ Please fill in all required fields correctly.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Check for banned words in title and description
    print('AsapListingForm: Starting word filter check...');
    print('AsapListingForm: Title: "${_titleController.text.trim()}"');
    print('AsapListingForm: Description: "${_descriptionController.text.trim()}"');

    try {
      final wordFilterService = WordFilterService();
      final fieldsToCheck = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      final bannedWordsByField = await wordFilterService.checkMultipleFields(fieldsToCheck);
      
      print('AsapListingForm: Banned words result: $bannedWordsByField');
      
      if (bannedWordsByField.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        
        print('AsapListingForm: Showing banned words dialog');
        // Show popup dialog with banned words
        await BannedWordsDialog.show(context, bannedWordsByField);
        return;
      } else {
        print('AsapListingForm: No banned words found, proceeding with creation');
      }
    } catch (e) {
      print('AsapListingForm: Error checking banned words: $e');
      // Continue with creation if word filter fails
    }

    List<String> imageUrls = _selectedImages.map((file) => 'https://example.com/images/${file.path.split('/').last}').toList();
    if (imageUrls.isEmpty) {
      imageUrls = ['https://placehold.co/600x400/000000/FFFFFF?text=No+Image'];
    }

    // Determine the final payment method
    String finalPaymentMethod = _selectedPaymentMethod!;
    if (_selectedPaymentMethod == 'Bank Transfer' && _selectedBank != null) {
      finalPaymentMethod = _selectedBank!; // Use specific bank instead of generic "Bank Transfer"
    }

    final asapService = AsapListingService();
    final response = await asapService.createAsapListing(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text),
      latitude: _listingLatitude!,
      longitude: _listingLongitude!,
      locationAddress: _locationAddressController.text.trim(),
      preferredDoerGender: _preferredDoerGender ?? 'Any',
      picturesUrls: imageUrls,
      paymentMethod: finalPaymentMethod,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message']);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/asap_doer_search',
          arguments: {
            'listing_id': response['listing_id'],
            'listing_latitude': _listingLatitude,
            'listing_longitude': _listingLongitude,
            'preferred_doer_gender': _preferredDoerGender ?? 'Any',
            'max_distance': 10.0,
          },
        );
      }
    } else {
      _showSnackBar('Failed to create ASAP listing: ${response['message']}', isError: true);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Set camera bounds to restrict map to Cavite area
    _mapController?.setMapStyle('''
      [
        {
          "featureType": "administrative.province",
          "elementType": "geometry.fill",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        }
      ]
    ''');
  }

  void _onMapTap(LatLng position) async {
    // First check basic coordinate bounds
    if (!_isLocationInCavite(position)) {
      _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
      return;
    }

    // Then validate using reverse geocoding (same as sign-up logic)
    bool isValidCaviteLocation = await _validateLocationByCaviteProvince(position);
    if (!isValidCaviteLocation) {
      _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
      return;
    }

    setState(() {
      _selectedLocation = position;
      _listingLatitude = position.latitude;
      _listingLongitude = position.longitude;
      _updateLocationMarker(position);
    });
    _reverseGeocodeLocation(position);
    _showSnackBar('📍 Location selected successfully!');
    print('📍 Location selected in Cavite: Lat: ${position.latitude}, Lng: ${position.longitude}');
  }

  void _updateLocationMarker(LatLng position) {
    setState(() {
      _locationMarker = Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        infoWindow: const InfoWindow(title: 'Selected Location'),
      );
    });
  }

  Future<void> _reverseGeocodeLocation(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build a comprehensive address string
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        String address = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';

        setState(() {
          _locationAddressController.text = address;
        });

        print('📍 Location selected: $address');
        _showSnackBar('📍 Location selected successfully!');
      } else {
        // Fallback to coordinates if no placemark found
        String address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
        setState(() {
          _locationAddressController.text = address;
        });
        print('📍 Location selected (coordinates): $address');
        _showSnackBar('📍 Location selected using coordinates!');
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      // Fallback to coordinates if geocoding fails
      String address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      setState(() {
        _locationAddressController.text = address;
      });
      _showSnackBar('📍 Location selected (geocoding unavailable)!');
    }
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      _showSnackBar('Maximum 5 images allowed.', isError: true);
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Widget _buildFeeRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'Php ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String title, String value) {
    final isSelected = _selectedPaymentMethod == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
          _selectedBank = null; // Clear bank selection when switching payment methods
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Constants.primaryColor : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? Constants.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Constants.primaryColor : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 20,
      endIndent: 20,
    );
  }

  Widget _buildBankTransferDropdown() {
    final isSelected = _selectedPaymentMethod == 'Bank Transfer';

    // List of working banks
    final workingBanks = [
      {'id': 'bpi', 'name': 'BPI Direct Debit'},
      {'id': 'chinabank', 'name': 'China Bank Direct Debit'},
      {'id': 'rcbc', 'name': 'RCBC Direct Debit'},
      {'id': 'unionbank', 'name': 'UBP Direct Debit'},
    ];

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_selectedPaymentMethod == 'Bank Transfer') {
                _selectedPaymentMethod = null;
                _selectedBank = null;
              } else {
                _selectedPaymentMethod = 'Bank Transfer';
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Constants.primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? Constants.primaryColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Bank Transfer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Constants.primaryColor : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (isSelected) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: workingBanks.map((bank) {
                final isBankSelected = _selectedBank == bank['id'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBank = bank['id'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isBankSelected ? Constants.primaryColor.withOpacity(0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBankSelected ? Constants.primaryColor : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            bank['name']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isBankSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isBankSelected ? Constants.primaryColor : Colors.black87,
                            ),
                          ),
                        ),
                        if (isBankSelected)
                          Icon(
                            Icons.check_circle,
                            color: Constants.primaryColor,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create ASAP Listing'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Type title here',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Doer Fee
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _pesoInputFormatters,
                decoration: InputDecoration(
                  labelText: 'Doer Fee *',
                  hintText: 'e.g., 500.00',
                  helperText: 'Minimum: Php 500.00 • Format: 0000.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: 'Php ',
                  prefixStyle: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a doer fee';
                  }

                  // Check if it matches our peso format
                  if (!_pesoRegex.hasMatch(value)) {
                    return 'Invalid format. Use numbers and decimal point only (e.g., 500.00)';
                  }

                  final price = double.tryParse(value);
                  if (price == null) {
                    return 'Please enter a valid number';
                  }

                  if (price <= 0) {
                    return 'Doer fee must be greater than zero';
                  }

                  if (price < 500) {
                    return 'Minimum doer fee is Php 500.00';
                  }

                  if (price > 999999.99) {
                    return 'Maximum doer fee is Php 999,999.99';
                  }

                  return null;
                },
                onChanged: (_) => _calculateFees(),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your task',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Location Search
              TextFormField(
                controller: _locationSearchController,
                decoration: InputDecoration(
                  labelText: 'Search Location in Cavite',
                  hintText: 'e.g., Imus, Dasmarinas, Bacoor, General Trias',
                  helperText: '📍 Service is only available in Cavite province',
                  helperStyle: TextStyle(color: Constants.primaryColor, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _geocodeAddress,
                        ),
                ),
                onFieldSubmitted: (value) => _geocodeAddress(),
              ),
              const SizedBox(height: 16),

              // Map
              Container(
                height: 200,
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
                      zoom: 11.0, // Zoom level to show most of Cavite
                    ),
                    markers: _locationMarker != null ? {_locationMarker!} : {},
                    onTap: _onMapTap,
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    cameraTargetBounds: CameraTargetBounds(_caviteBounds),
                    minMaxZoomPreference: const MinMaxZoomPreference(9.0, 18.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationAddressController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Selected Location *',
                  hintText: _locationAddressController.text.isEmpty
                      ? 'Tap on the map to select location'
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: _locationAddressController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _locationAddressController.clear();
                              _listingLatitude = null;
                              _listingLongitude = null;
                              _locationMarker = null;
                            });
                          },
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a location on the map';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Preferred Doer
              DropdownButtonFormField<String>(
                value: _preferredDoerGender,
                hint: const Text('Select preferred doer'),
                decoration: InputDecoration(
                  labelText: 'Preferred Doer *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_search),
                ),
                items: <String>['Any', 'Male', 'Female']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _preferredDoerGender = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a preferred doer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Images Section
              const Text(
                'Images (Optional)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._selectedImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    File image = entry.value;
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(image),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(idx),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_selectedImages.length < 5)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                          color: Colors.grey.shade100,
                        ),
                        child: const Icon(Icons.add_a_photo, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Payment Details
              const Text(
                'Payment Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Constants.primaryColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeeRow('Doer Fee', double.tryParse(_priceController.text) ?? 0.0),
                    _buildFeeRow('Transaction Fee', _doerFee),
                    const Divider(),
                    _buildFeeRow('Total Amount', _totalAmount, isTotal: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Methods
              const Text(
                'Payment Methods',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildPaymentOption('GCash', 'GCash'),
                    _buildDivider(),
                    _buildPaymentOption('GrabPay', 'GrabPay'),
                    _buildDivider(),
                    _buildPaymentOption('Maya', 'Maya'),
                    _buildDivider(),
                    _buildPaymentOption('Use HanApp Earnings', 'Use HanApp Earnings'),
                    _buildDivider(),
                    _buildPaymentOption('HanApp Balance', 'HanApp Balance'),
                    _buildDivider(),
                    _buildBankTransferDropdown(),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Next Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                text: 'Next',
                onPressed: _createAsapListing,
                color: Constants.primaryColor,
                textColor: Colors.white,
                borderRadius: 25.0,
                height: 50.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}