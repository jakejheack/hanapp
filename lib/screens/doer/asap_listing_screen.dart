// hanapp_flutter/lib/screens/owner/asap_listing_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'dart:io';
import 'package:hanapp/services/api_service.dart'; // Assuming this exists
import 'package:hanapp/screens/doer/asap_listing_map_screen.dart'; // Next screen in flow
import 'package:hanapp/utils/constants.dart';

import '../../utils/constants.dart' as Constants; // For colors and padding

class AsapListingScreen extends StatefulWidget {
  const AsapListingScreen({super.key});

  @override
  State<AsapListingScreen> createState() => _AsapListingScreenState();
}

class _AsapListingScreenState extends State<AsapListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _preferredDoer;
  String? _preferredDoerLocation;
  List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  bool _useGcash = false;
  bool _usePaymaya = false;
  bool _useBank = false;
  bool _useDebitCreditCard = false;
  bool _useHanAppEarnings = false;
  bool _useHanAppBalance = false;

  final double _doerFee = 350.00;
  final double _transactionFee = 35.00;

  double get _totalAmount => _doerFee + _transactionFee;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(image);
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final listingData = {
        'title': _titleController.text,
        'price': double.parse(_priceController.text),
        'description': _descriptionController.text,
        'location': _locationController.text,
        'preferred_doer': _preferredDoer,
        'preferred_doer_location': _preferredDoerLocation,
        'doer_fee': _doerFee,
        'transaction_fee': _transactionFee,
        'total_amount': _totalAmount,
        'payment_methods': {
          'gcash': _useGcash,
          'paymaya': _usePaymaya,
          'bank': _useBank,
          'debit_credit_card': _useDebitCreditCard,
          'hanapp_earnings': _useHanAppEarnings,
          'hanapp_balance': _useHanAppBalance,
        }
        // Images would need to be uploaded separately and references stored
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AsapListingMapScreen(listingData: listingData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asap Listing'), // Title from image
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: Constants.screenPadding, // Use consistent padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title', // Label from image
                  hintText: 'Type title here', // Hint from image
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price', // Label from image
                  hintText: 'Minimum of Php500', // Hint from image
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null || double.parse(value) < 500) {
                    return 'Price must be at least Php500';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description', // Label from image
                  hintText: 'Type your details here', // Hint from image
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location', // Label from image
                  hintText: 'Pin your exact location', // Hint from image
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _preferredDoer,
                decoration: const InputDecoration(
                  labelText: 'Preferred Doer', // Label from image
                  border: OutlineInputBorder(),
                ),
                items: ['Female', 'Male', 'Any'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _preferredDoer = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a preferred doer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _preferredDoerLocation,
                decoration: const InputDecoration(
                  labelText: 'Preferred Doer\'s Location', // Label from image
                  hintText: 'Within 1km', // Hint from image
                  border: OutlineInputBorder(),
                ),
                items: ['Within 1km', 'Within 5km', 'Anywhere'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _preferredDoerLocation = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Pictures', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Label from image
              const SizedBox(height: 8),
              Row(
                children: [
                  ..._images.map((img) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.file(File(img.path), width: 80, height: 80, fit: BoxFit.cover),
                  )).toList(),
                  if (_images.length < 3) // Allow up to 3 images as per image
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cloud_upload, size: 40, color: Colors.grey), // Upload icon from image
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Doer fee:', style: TextStyle(fontSize: 16)), // Label from image
                    Text('₱${_doerFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)), // Value from image
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction Fee:', style: TextStyle(fontSize: 16)), // Label from image
                    Text('₱${_transactionFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)), // Value from image
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Label from image
                    Text('₱${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Value from image
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 24),
              const Text('Payment Methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Label from image
              CheckboxListTile(
                title: const Text('GCash'), // Option from image
                value: _useGcash,
                onChanged: (bool? value) {
                  setState(() {
                    _useGcash = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Paymaya'), // Option from image
                value: _usePaymaya,
                onChanged: (bool? value) {
                  setState(() {
                    _usePaymaya = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Bank'), // Option from image
                value: _useBank,
                onChanged: (bool? value) {
                  setState(() {
                    _useBank = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Debit/Credit Card'), // Option from image
                value: _useDebitCreditCard,
                onChanged: (bool? value) {
                  setState(() {
                    _useDebitCreditCard = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Use your HanApp earnings'), // Option from image
                value: _useHanAppEarnings,
                onChanged: (bool? value) {
                  setState(() {
                    _useHanAppEarnings = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('HanApp Balance'), // Option from image
                value: _useHanAppBalance,
                onChanged: (bool? value) {
                  setState(() {
                    _useHanAppBalance = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              Text(
                "Don't worry - with HanApp Protect, your payment won't be released until the doer finishes the service. You can cancel or ask for a dispute anytime.", // Disclaimer from image
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor, // Blue button from image
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50), // Full width button
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Next'), // Button text from image
              ),
            ],
          ),
        ),
      ),
    );
  }
}