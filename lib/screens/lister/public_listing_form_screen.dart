import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:hanapp/utils/public_listing_service.dart'; // Use the updated ListingService
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/word_filter_service.dart';
import 'package:hanapp/widgets/banned_words_dialog.dart';

import '../components/custom_button.dart'; // Your constants

class PublicListingFormScreen extends StatefulWidget {
  const PublicListingFormScreen({super.key});

  @override
  State<PublicListingFormScreen> createState() => _PublicListingFormScreenState();
}

class _PublicListingFormScreenState extends State<PublicListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController();
  final TextEditingController _locationAddressController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(14.5995, 120.9842); // Default to Manila, Philippines
  Marker? _locationMarker;
  double? _listingLatitude;
  double? _listingLongitude;

  String? _selectedCategory; // NEW: 'Onsite', 'Hybrid', 'Remote'
  String? _preferredDoerGender; // 'Male', 'Female', 'Any'
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  String? _selectedPaymentMethod; // 'GCash', 'Paymaya', 'Bank', 'HanApp Earnings', 'HanApp Balance'

  bool _isLoading = false;

  // Fees (example values - might be optional for public listings)
  double _doerFee = 0.0;
  double _transactionFee = 0.0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _updateLocationMarker(_selectedLocation);
    _reverseGeocodeLocation(_selectedLocation);
    _calculateFees(); // Calculate initial fees
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation, 15.0));
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _updateLocationMarker(latLng);
      _listingLatitude = latLng.latitude;
      _listingLongitude = latLng.longitude;
    });
    _reverseGeocodeLocation(latLng);
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
      _doerFee = price; // Doer fee is the price of the listing
      _transactionFee = 25.0; // Fixed transaction fee at 25 PHP
      _totalAmount = _doerFee + _transactionFee;
    });
  }
  

  Future<void> _createPublicListing() async {
    if (_formKey.currentState!.validate()) {
      if ((_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') && (_listingLatitude == null || _listingLongitude == null || _locationAddressController.text.isEmpty)) {
        _showSnackBar('Location is required for Onsite/Hybrid listings. Please select on map or search.', isError: true);
        return;
      }
      if (_selectedPaymentMethod == null && (_priceController.text.isNotEmpty && double.tryParse(_priceController.text) != null && double.parse(_priceController.text) > 0)) {
        _showSnackBar('Please select a payment method if a price is specified.', isError: true);
        return;
      }

      // Check for banned words in title and description
      setState(() {
        _isLoading = true;
      });

      print('PublicListingForm: Starting word filter check...');
      print('PublicListingForm: Title: "${_titleController.text.trim()}"');
      print('PublicListingForm: Description: "${_descriptionController.text.trim()}"');

      try {
        final wordFilterService = WordFilterService();
        final fieldsToCheck = {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
        };

        final bannedWordsByField = await wordFilterService.checkMultipleFields(fieldsToCheck);
        
        print('PublicListingForm: Banned words result: $bannedWordsByField');
        
        if (bannedWordsByField.isNotEmpty) {
          setState(() {
            _isLoading = false;
          });
          
          print('PublicListingForm: Showing banned words dialog');
          // Show popup dialog with banned words
          await BannedWordsDialog.show(context, bannedWordsByField);
          return;
        } else {
          print('PublicListingForm: No banned words found, proceeding with creation');
        }
      } catch (e) {
        print('PublicListingForm: Error checking banned words: $e');
        // Continue with creation if word filter fails
      }

      List<String> imageUrls = _selectedImages.map((file) => 'https://example.com/images/${file.path.split('/').last}').toList();
      if (imageUrls.isEmpty) {
        imageUrls = ['https://placehold.co/600x400/000000/FFFFFF?text=No+Image'];
      }

      final response = await ListingService().createListing( // Use ListingService
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text), // Can be null
        category: _selectedCategory ?? 'Onsite', // NEW: Pass category
        latitude: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _listingLatitude : null,
        longitude: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _listingLongitude : null,
        locationAddress: (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid') ? _locationAddressController.text.trim() : null,
        preferredDoerGender: _preferredDoerGender ?? 'Any',
        picturesUrls: imageUrls,
        paymentMethod: _selectedPaymentMethod, // Can be null
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        _showSnackBar(response['message']);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/public_listing_details', // Navigate to public listing details
            arguments: {'listing_id': response['listing_id']},
          );
        }
      } else {
        _showSnackBar('Failed to create Public Listing: ${response['message']}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showLocationFields = (_selectedCategory == 'Onsite' || _selectedCategory == 'Hybrid');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Listing'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Public Listing',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 24),

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

              // Category Selection
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
                    // Reset location fields if category changes to Remote
                    if (newValue == 'Remote') {
                      _listingLatitude = null;
                      _listingLongitude = null;
                      _locationAddressController.clear();
                      _locationSearchController.clear();
                      _locationMarker = null; // Clear map marker
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price (Optional for Public Listing)
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price (Optional)',
                  hintText: 'Enter price (e.g., 500.00)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixText: 'Php ',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Please enter a valid positive price or leave empty';
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

              // Location Section (Conditional based on category)
              if (showLocationFields) ...[
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    labelText: 'Resolved Address',
                    hintText: 'Address will appear here',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Preferred Doer (Optional for Public Listing)
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

              // Payment Details Summary (Conditional based on price)
              if (_priceController.text.isNotEmpty && double.tryParse(_priceController.text) != null && double.parse(_priceController.text) > 0) ...[
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
                      _buildFeeRow('Doer Fee', _doerFee),
                      _buildFeeRow('Transaction Fee', _transactionFee),
                      const Divider(),
                      _buildFeeRow('Total Amount', _totalAmount, isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Methods (Conditional based on price)
                const Text(
                  'Payment Methods',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    _buildPaymentMethodRadio('GCash'),
                    _buildPaymentMethodRadio('Paymaya'),
                    _buildPaymentMethodRadio('Bank'),
                    _buildPaymentMethodRadio('Use HanApp Earnings'),
                    _buildPaymentMethodRadio('HanApp Balance'),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // Next Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                text: 'Next',
                onPressed: _createPublicListing,
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

  Widget _buildPaymentMethodRadio(String method) {
    return RadioListTile<String>(
      title: Text(method),
      value: method,
      groupValue: _selectedPaymentMethod,
      onChanged: (String? value) {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      activeColor: Constants.primaryColor,
    );
  }
}