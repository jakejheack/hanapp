import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;

// Import both listing services
import 'package:hanapp/utils/asap_listing_service.dart';
import 'package:hanapp/utils/public_listing_service.dart'; // For public listings
import 'package:hanapp/models/asap_listing.dart'; // Import both models for editing
import 'package:hanapp/models/public_listing.dart';

import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/word_filter_service.dart';
import 'package:hanapp/widgets/banned_words_dialog.dart';
import 'package:hanapp/screens/components/custom_button.dart'; // Assuming CustomButton exists

class CombinedListingFormScreen extends StatefulWidget {
  final int? listingId; // Optional: for editing existing listing
  final String? listingType; // Optional: 'ASAP' or 'Public' for editing

  const CombinedListingFormScreen({super.key, this.listingId, this.listingType});

  @override
  State<CombinedListingFormScreen> createState() => _CombinedListingFormScreenState();
}

class _CombinedListingFormScreenState extends State<CombinedListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController(); // NEW: Tags controller for Public listings



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

  String? _selectedListingType; // 'ASAP' or 'Public' - determines form behavior
  String? _selectedCategory; // 'Onsite', 'Hybrid', 'Remote' - only for Public listings
  String? _preferredDoerGender; // 'Male', 'Female', 'Any'
  List<File> _selectedImages = []; // For local image files to be uploaded
  final ImagePicker _picker = ImagePicker();

  String? _selectedPaymentMethod;
  String? _selectedBank; // For bank transfer selection

  bool _isLoading = false; // General loading indicator
  bool _isEditing = false; // Flag to indicate if we are editing an existing listing

  double _doerFee = 0.0;
  double _transactionFee = 0.0;
  double _totalAmount = 0.0;

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
  void initState() {
    super.initState();
    // Initialize map and location defaults
    _updateLocationMarker(_selectedLocation);
    _reverseGeocodeLocation(_selectedLocation);
    _calculateFees(); // Calculate initial fees based on empty price

    // Check if we are in edit mode
    if (widget.listingId != null && widget.listingType != null) {
      _isEditing = true;
      _selectedListingType = widget.listingType; // Set the listing type based on what's being edited
      _loadListingForEdit(widget.listingId!, widget.listingType!);
    } else {
      // For new listing creation, default to ASAP and show its warning
      _selectedListingType = 'ASAP';
      _showAsapWarningDialog();
    }
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

  // NEW: Method to load existing listing data for editing
  Future<void> _loadListingForEdit(int id, String type) async {
    setState(() {
      _isLoading = true; // Show loading indicator while fetching data
    });

    dynamic response;
    if (type == 'ASAP') {
      response = await AsapListingService().getAsapListingDetails(id);
    } else { // Public
      response = await ListingService().getListingDetails(id);
    }

    setState(() {
      _isLoading = false; // Hide loading indicator after fetch
    });

    if (response['success']) {
      if (type == 'ASAP') {
        AsapListing listing = response['listing'];
        _titleController.text = listing.title;
        _descriptionController.text = listing.description ?? '';
        _priceController.text = listing.price.toString();
        _listingLatitude = listing.latitude;
        _listingLongitude = listing.longitude;
        _locationAddressController.text = listing.locationAddress ?? '';
        _preferredDoerGender = listing.preferredDoerGender;
        _selectedPaymentMethod = listing.paymentMethod;
        // For images, if you have URLs, you'd typically display them as network images
        // and allow new uploads to replace/add. Re-populating _selectedImages with File objects
        // from network URLs is complex and usually not done directly for editing.
        // For simplicity, existing images remain, and new uploads are handled.
        _selectedImages.clear(); // Clear any dummy images
        // You might want to populate a separate list for displaying existing network images
        // For example: List<String> _existingImageUrls = listing.picturesUrls ?? [];

      } else { // Public
        PublicListing listing = response['listing'];
        _titleController.text = listing.title;
        _descriptionController.text = listing.description ?? '';
        _priceController.text = listing.price?.toString() ?? '';
        _selectedCategory = listing.category;
        _listingLatitude = listing.latitude;
        _listingLongitude = listing.longitude;
        _locationAddressController.text = listing.locationAddress ?? '';
        _preferredDoerGender = listing.preferredDoerGender;
        _tagsController.text = listing.tags ?? ''; // NEW: Populate tags field
        _selectedPaymentMethod = listing.paymentMethod;
        _selectedImages.clear(); // Clear any dummy images
      }

      // Update map and fees after data is loaded
      if (_listingLatitude != null && _listingLongitude != null) {
        _selectedLocation = LatLng(_listingLatitude!, _listingLongitude!);
        _updateLocationMarker(_selectedLocation);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15.0));
      }
      _calculateFees();
    } else {
      _showSnackBar('Failed to load listing for editing: ${response['message']}', isError: true);
      if (mounted) {
        Navigator.of(context).pop(); // Go back if loading fails
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationSearchController.dispose();
    _locationAddressController.dispose();
    _tagsController.dispose(); // Dispose tags controller
    _mapController?.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    // Clear any existing snackbars first
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15.0));
  }

  void _onMapTap(LatLng latLng) async {
    // First check basic coordinate bounds
    if (!_isLocationInCavite(latLng)) {
      _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
      return;
    }

    // Then validate using reverse geocoding (same as sign-up logic)
    bool isValidCaviteLocation = await _validateLocationByCaviteProvince(latLng);
    if (!isValidCaviteLocation) {
      _showSnackBar("Sorry, it's currently unavailable in your area. We're planning to expand soon.", isError: true);
      return;
    }

    setState(() {
      _selectedLocation = latLng;
      _updateLocationMarker(latLng);
      _listingLatitude = latLng.latitude;
      _listingLongitude = latLng.longitude;
    });
    _reverseGeocodeLocation(latLng);
    _showSnackBar('📍 Location selected successfully!');
    print('📍 Location selected in Cavite: Lat: ${latLng.latitude}, Lng: ${latLng.longitude}');
  }

  void _updateLocationMarker(LatLng latLng) {
    setState(() {
      _locationMarker = Marker(
        markerId: const MarkerId('listing_location'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Listing Location'),
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
      // Use location-biased geocoding with Philippines region for better accuracy
      List<Location> locations = await geocoding.locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        // If multiple results, show the most accurate one first
        // Sort by relevance (closer to Philippines center if available)
        final philippinesCenter = const LatLng(14.5995, 120.9842); // Manila
        locations.sort((a, b) {
          final distA = _calculateDistance(
            a.latitude, a.longitude, 
            philippinesCenter.latitude, philippinesCenter.longitude
          );
          final distB = _calculateDistance(
            b.latitude, b.longitude, 
            philippinesCenter.latitude, philippinesCenter.longitude
          );
          return distA.compareTo(distB);
        });
        
        final latLng = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _selectedLocation = latLng;
          _updateLocationMarker(latLng);
          _listingLatitude = latLng.latitude;
          _listingLongitude = latLng.longitude;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 18.0)); // Higher zoom for accuracy
        _showSnackBar('Location found! Tap the map to fine-tune if needed.');
        _reverseGeocodeLocation(latLng);
      } else {
        _showSnackBar('Address not found. Please try a more specific address or landmark.', isError: true);
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

  // Helper function to calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Future<void> _reverseGeocodeLocation(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        latLng.latitude, 
        latLng.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Create a more detailed and accurate address format
        List<String> addressComponents = [];
        
        // Add street name if available
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressComponents.add(placemark.street!);
        }
        
        // Add sublocality (barangay/district) if available
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          addressComponents.add(placemark.subLocality!);
        }
        
        // Add locality (city/municipality) if available
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressComponents.add(placemark.locality!);
        }
        
        // Add administrative area (province) if available
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          addressComponents.add(placemark.administrativeArea!);
        }
        
        // Add postal code if available
        if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
          addressComponents.add(placemark.postalCode!);
        }
        
        // Add country if not Philippines (should be Philippines for local addresses)
        if (placemark.country != null && placemark.country!.isNotEmpty && placemark.country != 'Philippines') {
          addressComponents.add(placemark.country!);
        }
        
        // Join all components with commas
        String address = addressComponents.join(', ');
        
        // If we have a very detailed address, use it; otherwise, fall back to the original search
        if (addressComponents.length >= 3) {
          _locationAddressController.text = address;
        } else {
          // Fall back to the original search term if reverse geocoding is too generic
          _locationAddressController.text = _locationSearchController.text.trim();
        }
        
        debugPrint('Reverse geocoded address: $address');
      } else {
        _locationAddressController.text = _locationSearchController.text.trim();
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      _locationAddressController.text = _locationSearchController.text.trim();
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _calculateFees() {
    double price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      if (_selectedListingType == 'ASAP') {
        // Fixed doer fee for ASAP listings
        _doerFee = 25.0;
        _transactionFee = 0.0;
        _totalAmount = price + _doerFee;
      } else {
        // For Public listings: Doer fee is the price, transaction fee is fixed at 25 PHP
        _doerFee = price; // Doer fee is the price of the listing
        _transactionFee = 25.0; // Fixed transaction fee at 25 PHP
        _totalAmount = _doerFee + _transactionFee;
      }
    });
  }



  // --- Warning Dialogs ---
  Future<void> _showAsapWarningDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'WARNING!',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'ASAP listings are for onsite work only. Any task that can be done online is prohibited.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 10),
                Text(
                  'The task you are posting should also be something urgent or something you need immediate help with.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 15),
                Text(
                  'If it\'s not urgent, please post it under the Public Listing instead.',
                  textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 15),
                Text(
                  'Doers may report you if they see you posting something inappropriate for ASAP. This may cause you to be recommended less — and worse, you could get banned from the platform.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Center(
              child: CustomButton(
                text: 'Understood',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                color: Constants.primaryColor,
                textColor: Colors.white,
                borderRadius: 10.0, height: 45.0, width: 150,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPublicListingWarningDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'WARNING!',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Requests like... "Please help me sell", "Sell my...", "Commission for selling." or anything that asks other Doers to sell your items are not allowed on this platform.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 15),
                Text(
                  'Doing so may trigger the AI and the system, causing you to be recommended less and worse, you could get banned from the platform.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Center(
              child: CustomButton(
                text: 'Understood',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                color: Constants.primaryColor,
                textColor: Colors.white,
                borderRadius: 10.0, height: 45.0, width: 150,
              ),
            ),
          ],
        );
      },
    );
  }
  // --- End Warning Dialogs ---

  // NEW: _submitListing now handles both create and update based on _isEditing
  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation specific to location based on category for Public listings
    if (_selectedListingType == 'Public' && (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid')) {
      if (_listingLatitude == null || _listingLongitude == null || _locationAddressController.text.isEmpty) {
        _showSnackBar('Location is required for Onsite/Hybrid Public listings. Please select on map or search.', isError: true);
        return;
      }
    }

    // Validation for payment method if price is set
    if (_priceController.text.isNotEmpty && double.tryParse(_priceController.text) != null && double.parse(_priceController.text) > 0) {
      if (_selectedPaymentMethod == null) {
        _showSnackBar('💳 Please select a payment method from the Payment Methods section.', isError: true);
        return;
      }
    } else if (_selectedListingType == 'ASAP') {
      final price = double.tryParse(_priceController.text);
      if (_priceController.text.isEmpty || price == null || price <= 0) {
        _showSnackBar('❌ Price is required for ASAP listings. Please enter a price.', isError: true);
        return;
      }
      if (price < 500) {
        _showSnackBar('❌ Price must be at least Php 500 for ASAP listings. Please check the Price field.', isError: true);
        return;
      }
    }
    // Also ensure payment method is selected for ASAP if price is entered
    if (_selectedListingType == 'ASAP' && _selectedPaymentMethod == null) {
      _showSnackBar('Payment method is required for ASAP listings.', isError: true);
      return;
    }


    setState(() {
      _isLoading = true;
    });

    // Check for banned words in title and description
    print('CombinedListingForm: Starting word filter check...');
    print('CombinedListingForm: Title: "${_titleController.text.trim()}"');
    print('CombinedListingForm: Description: "${_descriptionController.text.trim()}"');

    try {
      final wordFilterService = WordFilterService();
      final fieldsToCheck = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      // Add tags to check if it's a Public listing
      if (_selectedListingType == 'Public' && _tagsController.text.trim().isNotEmpty) {
        fieldsToCheck['tags'] = _tagsController.text.trim();
      }

      final bannedWordsByField = await wordFilterService.checkMultipleFields(fieldsToCheck);
      
      print('CombinedListingForm: Banned words result: $bannedWordsByField');
      
      if (bannedWordsByField.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        
        print('CombinedListingForm: Showing banned words dialog');
        // Show popup dialog with banned words
        await BannedWordsDialog.show(context, bannedWordsByField);
        return;
      } else {
        print('CombinedListingForm: No banned words found, proceeding with creation');
      }
    } catch (e) {
      print('CombinedListingForm: Error checking banned words: $e');
      // Continue with creation if word filter fails
    }

    // In a real app, you'd upload images to a storage service (e.g., Firebase Storage, AWS S3)
    // and get their URLs before sending them to your PHP backend.
    // For this example, we'll send dummy URLs or an empty array.
    List<String> imageUrls = _selectedImages.map((file) => 'https://example.com/images/${file.path.split('/').last}').toList();
    if (imageUrls.isEmpty) {
      imageUrls = ['https://placehold.co/600x400/000000/FFFFFF?text=No+Image']; // Default placeholder
    }

    dynamic response;
    if (_selectedListingType == 'ASAP') {
      if (_isEditing && widget.listingId != null) {
        // Construct AsapListing object for update
        AsapListing updatedListing = AsapListing(
          id: widget.listingId!,
          listerId: 0, // listerId is not updated via this form, backend handles it
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text),
          latitude: _listingLatitude!,
          longitude: _listingLongitude!,
          locationAddress: _locationAddressController.text.trim(),
          preferredDoerGender: _preferredDoerGender ?? 'Any',
          picturesUrls: imageUrls,
          paymentMethod: _selectedPaymentMethod!,
          status: 'pending', // Status is typically managed by backend workflow
          isActive: true, // is_active is managed by backend or separate toggle
          createdAt: DateTime.now(), // Dummy, not used for update
          updatedAt: DateTime.now(), listingType: 'ASAP', // Dummy, not used for update
        );
        response = await AsapListingService().updateAsapListing(updatedListing);
      } else {
        // Create new ASAP listing
        response = await AsapListingService().createAsapListing(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text),
          latitude: _listingLatitude!,
          longitude: _listingLongitude!,
          locationAddress: _locationAddressController.text.trim(),
          preferredDoerGender: _preferredDoerGender ?? 'Any',
          picturesUrls: imageUrls,
          paymentMethod: _selectedPaymentMethod!,
        );
      }
    } else if (_selectedListingType == 'Public') {
      if (_isEditing && widget.listingId != null) {
        // Construct Listing object for update
        PublicListing updatedListing = PublicListing(
          id: widget.listingId!,
          listerId: 0, // listerId is not updated via this form
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.tryParse(_priceController.text),
          category: _selectedCategory ?? 'Onsite',
          latitude: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _listingLatitude : null,
          longitude: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _listingLongitude : null,
          locationAddress: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _locationAddressController.text.trim() : null,
          preferredDoerGender: _preferredDoerGender ?? 'Any',
          picturesUrls: imageUrls,
          tags: _tagsController.text.trim().isEmpty ? null : _tagsController.text.trim(), // NEW: Tags for update
          paymentMethod: _selectedPaymentMethod,
          status: 'open', // Status is typically managed by backend workflow
          isActive: true, // is_active is managed by backend or separate toggle
          createdAt: DateTime.now(), // Dummy, not used for update
          updatedAt: DateTime.now(), listingType: 'Public', // Dummy, not used for update
        );
        response = await ListingService().updateListing(updatedListing);
      } else {
        // Create new Public listing
        response = await ListingService().createListing(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.tryParse(_priceController.text),
          category: _selectedCategory ?? 'Onsite',
          latitude: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _listingLatitude : null,
          longitude: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _listingLongitude : null,
          locationAddress: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _locationAddressController.text.trim() : null,
          preferredDoerGender: _preferredDoerGender ?? 'Any',
          picturesUrls: imageUrls,
          tags: _tagsController.text.trim().isEmpty ? null : _tagsController.text.trim(), // NEW: Tags for creation
          paymentMethod: _selectedPaymentMethod,
        );
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (response != null && response['success']) {
      _showSnackBar(response['message']);
      if (mounted) {
        // After successful creation/update, navigate back or to details screen
        if (_selectedListingType == 'ASAP') {
          Navigator.of(context).pushReplacementNamed(
            '/asap_listing_details',
            arguments: {'listing_id': response['listing_id'] ?? widget.listingId}, // Use new ID or existing
          );
        } else { // Public Listing
          Navigator.of(context).pushReplacementNamed(
            '/public_listing_details',
            arguments: {'listing_id': response['listing_id'] ?? widget.listingId}, // Use new ID or existing
          );
        }
      }
    } else {
      _showSnackBar('Failed to ${_isEditing ? 'update' : 'create'} listing: ${response?['message'] ?? 'Unknown error'}', isError: true);
    }
  }

  // Helper to reset location-related fields
  void _resetLocationFields() {
    _listingLatitude = null;
    _listingLongitude = null;
    _locationAddressController.clear();
    _locationSearchController.clear();
    _locationMarker = null;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(const LatLng(14.5995, 120.9842), 10.0)); // Reset map view
  }

  @override
  Widget build(BuildContext context) {
    bool isAsap = _selectedListingType == 'ASAP';
    // Show location fields if it's ASAP, or if it's Public and category is Onsite/Hybrid
    bool showLocationFields = isAsap || (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid');
    // Show payment section if price is entered and valid
    bool showPaymentSection = _priceController.text.isNotEmpty && double.tryParse(_priceController.text) != null && double.parse(_priceController.text) > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Listing' : 'Enter Listing Details'), // Title changes based on mode
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _isEditing && _titleController.text.isEmpty // Show loading indicator while fetching data for edit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Listing Type Selector (ASAP vs Public) - Disabled in Edit Mode
              const Text(
                'Listing Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _isEditing ? Colors.grey.shade200 : Colors.white, // Grey out in edit mode
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedListingType,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none, // Remove default border
                    prefixIcon: Icon(Icons.list_alt),
                  ),
                  items: <String>['ASAP', 'Public']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: _isEditing ? null : (String? newValue) { // Disable type change in edit mode
                    setState(() {
                      _selectedListingType = newValue;
                      if (newValue == 'ASAP') {
                        _selectedCategory = null; // Clear category for ASAP
                        _tagsController.clear(); // Clear tags for ASAP
                        _showAsapWarningDialog();
                      } else { // Switched to Public
                        _showPublicListingWarningDialog();
                      }
                      _resetLocationFields(); // Reset map and address on type change
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Category Selection (only for Public listings)
              if (!isAsap) ...[
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  hint: const Text('Select Category'),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: <String>['Onsite', 'Hybrid', 'Remote']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                      if (newValue == 'Remote') {
                        _resetLocationFields();
                      } else {
                        // If switching back to Onsite/Hybrid, ensure map is reset to default or current location
                        _updateLocationMarker(_selectedLocation);
                        _reverseGeocodeLocation(_selectedLocation);
                      }
                    });
                  },
                  validator: (value) {
                    if (!isAsap && (value == null || value.isEmpty)) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

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

              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _pesoInputFormatters,
                decoration: InputDecoration(
                  labelText: isAsap ? 'Price *' : 'Price (Optional)',
                  hintText: isAsap ? 'e.g., 500.00' : 'e.g., 500.00 (optional)',
                  helperText: isAsap ? 'Minimum: Php 500.00 • Format: 0000.00' : 'Format: 0000.00',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: 'Php ',
                  prefixStyle: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                validator: (value) {
                  if (isAsap) { // Price is required for ASAP
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price for ASAP listing';
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
                      return 'Price must be greater than zero';
                    }

                    if (price < 500) {
                      return 'Minimum price is Php 500.00 for ASAP listings';
                    }

                    if (price > 999999.99) {
                      return 'Maximum price is Php 999,999.99';
                    }
                  } else { // Price is optional for Public
                    if (value != null && value.isNotEmpty) {
                      // Check if it matches our peso format
                      if (!_pesoRegex.hasMatch(value)) {
                        return 'Invalid format. Use numbers and decimal point only (e.g., 500.00)';
                      }

                      final price = double.tryParse(value);
                      if (price == null) {
                        return 'Please enter a valid number';
                      }

                      if (price <= 0) {
                        return 'Price must be greater than zero';
                      }

                      if (price > 999999.99) {
                        return 'Maximum price is Php 999,999.99';
                      }
                    }
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
                  hintText: 'Type your details here',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Tags (only for Public listings)
              if (!isAsap) ...[
                TextFormField(
                  controller: _tagsController,
                  decoration: InputDecoration(
                    labelText: 'Tags (Optional)',
                    hintText: 'ex. palaba, pahugas, pabuhat, etc.', // Matches image
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Location Section (Conditional based on category for Public, always for ASAP)
              if (showLocationFields) ...[
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                ),
                const SizedBox(height: 8),
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
                  controller: _locationAddressController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Selected Location *',
                    hintText: _locationAddressController.text.isEmpty
                        ? 'Tap on the map or search to select location'
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
                    // Only validate if location is required for the selected category
                    if (_selectedListingType == 'ASAP' ||
                        (_selectedListingType == 'Public' &&
                         (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid'))) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a location on the map';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Preferred Doer
              DropdownButtonFormField<String>(
                value: _preferredDoerGender,
                hint: const Text('Preferred Doer (Optional)'),
                decoration: InputDecoration(
                  labelText: 'Preferred Doer (Optional)',
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
              ),
              const SizedBox(height: 24),

              // Pictures
              const Text(
                'Pictures',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
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
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => _removeImage(idx),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Icon(Icons.add_a_photo, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Payment Details Summary (Conditional based on price being set)
              if (showPaymentSection) ...[
                const Text(
                  'Payment Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
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
                      _buildFeeRow('Doer Fee', _doerFee),
                      _buildFeeRow('Transaction Fee', _transactionFee),
                      const Divider(),
                      _buildFeeRow('Total Amount', _totalAmount, isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Methods (Conditional based on price being set)
                const Text(
                  'Payment Methods',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
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
              ],

              // Submit Button
              _isLoading && !_isEditing // Show loading only for initial fetch in edit mode, or for submission
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                text: _isEditing ? 'Update Listing' : 'Save', // Button text changes based on mode
                onPressed: _submitListing,
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

  Widget _buildFeeRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Constants.textColor : Colors.grey.shade800,
            ),
          ),
          Text(
            'Php ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Constants.primaryColor : Colors.grey.shade800,
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
}
