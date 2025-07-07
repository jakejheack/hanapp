import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/listing_service.dart';
import 'package:hanapp/utils/location_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EnterAsapListingDetailsScreen extends StatefulWidget {
  const EnterAsapListingDetailsScreen({super.key});

  @override
  State<EnterAsapListingDetailsScreen> createState() => _EnterAsapListingDetailsScreenState();
}

class _EnterAsapListingDetailsScreenState extends State<EnterAsapListingDetailsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _selectedGender;
  XFile? _pickedXFile;
  final ImagePicker _picker = ImagePicker();
  final ListingService _listingService = ListingService();
  final LocationService _locationService = LocationService();
  User? _currentUser;
  bool _isLoading = false;

  // Payment related fields
  double _doerFee = 350.0;
  double _transactionFee = 35.0;
  double _totalAmount = 385.0;
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _priceController.addListener(_updateTotalAmount);
  }

  @override
  void dispose() {
    _priceController.removeListener(_updateTotalAmount);
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _updateTotalAmount() {
    try {
      double price = double.parse(_priceController.text);
      // Assuming transaction fee is 10% of the price if price is the base for doer fee
      // or if it's a fixed transaction fee regardless of price.
      // For now, using fixed values from the image.
      // If price dictates doer fee, this logic needs to be adjusted.
      // For simplicity, let's assume price is the base for calculation.
      // If price is the 'Doer Fee', then total is price + transaction fee.
      // If price is the 'Total Amount', then doer fee and transaction fee are calculated.
      // Based on the image, "Price" is an input field, and "Doer Fee", "Transaction Fee", "Total Amount" are derived.
      // Let's assume the input 'Price' is the 'Doer Fee'.
      _doerFee = price;
      _transactionFee = price * 0.10; // Assuming 10% transaction fee
      _totalAmount = _doerFee + _transactionFee;
    } catch (e) {
      _doerFee = 0.0;
      _transactionFee = 0.0;
      _totalAmount = 0.0;
    }
    setState(() {});
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
    setState(() {});
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile;
      });
    }
  }

  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.of(context).pushNamed('/select_location_on_map') as Map<String, dynamic>?;

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _addressController.text = result['address'];
      });
    }
  }

  Future<void> _createAsapListing() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }
    if (_titleController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _latitude == null ||
        _longitude == null ||
        _selectedGender == null ||
        _radiusController.text.isEmpty ||
        _selectedPaymentMethod == null) { // Ensure payment method is selected
      _showSnackBar('Please fill all required fields and select a payment method.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _listingService.createListing(
        listerId: _currentUser!.id.toString(),
        title: _titleController.text,
        price: double.parse(_priceController.text), // This is the doer fee
        description: _descriptionController.text,
        address: _addressController.text,
        latitude: _latitude!,
        longitude: _longitude!,
        listingType: 'asap',
        preferredDoerGender: _selectedGender,
        preferredDoerLocationRadius: double.parse(_radiusController.text),
        imageFile: _pickedXFile != null ? File(_pickedXFile!.path) : null,
        // Payment method information would typically be handled on the backend
        // or passed as a separate field if needed for listing creation.
        // For now, it's a UI selection.
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        _showSnackBar(response['message']);
        // Navigate to the "Searching for a doer..." screen
        Navigator.of(context).pushReplacementNamed('/awaiting_listing', arguments: {
          'listingTitle': _titleController.text,
          'listingAddress': _addressController.text,
          'latitude': _latitude,
          'longitude': _longitude,
        });
      } else {
        _showSnackBar('Failed to create ASAP listing: ${response['message']}', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error creating ASAP listing: $e', isError: true);
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
      appBar: AppBar(
        title: const Text('ASAP Listing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Title',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Type title here',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Price',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Min amount of Php500',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type your details here',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Tap to select your location',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: _selectLocationOnMap,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Preferred Doer Gender',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                hintText: 'Select preferred gender',
                border: OutlineInputBorder(),
              ),
              items: <String>['Any', 'Male', 'Female', 'Other']
                  .map<DropdownMenuItem<String>>((String value) {
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
            ),
            const SizedBox(height: 16),
            const Text(
              'Preferred Doer Location (radius in km)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g., 5 (for 5 km)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pictures',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _pickedXFile == null
                    ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                    : kIsWeb
                    ? Image.network(_pickedXFile!.path, fit: BoxFit.cover)
                    : Image.file(File(_pickedXFile!.path), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            // Payment Details Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Doer Fee', style: TextStyle(fontSize: 16)),
                    Text('₱${_doerFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction Fee', style: TextStyle(fontSize: 16)),
                    Text('₱${_transactionFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₱${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payment Methods',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  title: const Text('GCash'),
                  value: 'GCash',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Paymaya'),
                  value: 'Paymaya',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Bank'),
                  value: 'Bank',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Debit/Credit Card'),
                  value: 'Debit/Credit Card',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Use your HanApp earnings'),
                  value: 'HanApp Earnings',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('HanApp Balance'),
                  value: 'HanApp Balance',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedPaymentMethod = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Don't worry - with HanApp Protect, your payment won't be released until you confirm the service. You can cancel or ask for a dispute anytime.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomButton(
              text: 'Next',
              onPressed: _createAsapListing,
            ),
          ],
        ),
      ),
    );
  }
}