import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/utils/listing_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/listing.dart'; // Import Listing model
import 'package:cached_network_image/cached_network_image.dart'; // For displaying network image
import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb

class EnterListingDetailsScreen extends StatefulWidget {
  // We no longer need initialListing as a constructor parameter for named routes
  const EnterListingDetailsScreen({super.key});

  @override
  State<EnterListingDetailsScreen> createState() => _EnterListingDetailsScreenState();
}

class _EnterListingDetailsScreenState extends State<EnterListingDetailsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController(); // Comma-separated tags

  File? _listingImageFile;
  String? _currentImageUrl; // To hold the URL of the existing image if editing
  final ImagePicker _picker = ImagePicker();
  final ListingService _listingService = ListingService();
  bool _isLoading = false;
  User? _currentUser; // To get lister_id
  Listing? _listingToEdit; // State variable to hold the listing if editing

  bool get _isEditing => _listingToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only retrieve arguments and populate fields once
    if (_listingToEdit == null) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is Listing) {
        _listingToEdit = args;
        // Populate controllers with existing listing data
        _titleController.text = _listingToEdit!.title;
        _priceController.text = _listingToEdit!.price.toStringAsFixed(2);
        _descriptionController.text = _listingToEdit!.description;
        _addressController.text = _listingToEdit!.address;
        _categoryController.text = _listingToEdit!.category ?? '';
        _tagsController.text = _listingToEdit!.tags ?? ''; // Corrected this line
        _currentImageUrl = _listingToEdit!.imageUrl;
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      // Handle case where user is not found (e.g., navigate to login)
      Navigator.of(context).pushReplacementNamed('/login');
    } else if (_currentUser!.role != 'lister') {
      // Prevent non-listers from accessing this screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Listers can create/edit listings.')),
      );
      Navigator.of(context).pop(); // Go back
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _listingImageFile = File(pickedFile.path);
        _currentImageUrl = null; // Clear current image URL if a new one is picked
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

  Future<void> _handleSaveOrUpdate() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in or ID missing.', isError: true);
      return;
    }

    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _addressController.text.isEmpty) {
      _showSnackBar('Please fill all required fields.', isError: true);
      return;
    }

    if (!_isEditing && _priceController.text.isEmpty) {
      _showSnackBar('Please enter a price for the new listing.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> response;

    if (_isEditing) {
      response = await _listingService.updateListing(
        listingId: _listingToEdit!.id,
        listerId: _currentUser!.id!,
        title: _titleController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        category: _categoryController.text.isNotEmpty ? _categoryController.text : null,
        tags: _tagsController.text.isNotEmpty ? _tagsController.text : null,
        imageFile: _listingImageFile,
        currentImageUrl: _currentImageUrl, // Pass current image URL for backend logic
      );
    } else {
      response = await _listingService.createListing(
        listerId: _currentUser!.id.toString(),
        title: _titleController.text,
        price: double.parse(_priceController.text),
        description: _descriptionController.text,
        address: _addressController.text,
        category: _categoryController.text.isNotEmpty ? _categoryController.text : null,
        tags: _tagsController.text.isNotEmpty ? _tagsController.text : null,
        imageFile: _listingImageFile, latitude: 00000,longitude: 00000,
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message']);
      Navigator.of(context).pop(); // Go back to dashboard or listings
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Listing' : 'Enter Listing Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (₱)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              readOnly: _isEditing, // Make price read-only if editing
              style: _isEditing ? const TextStyle(color: Colors.grey) : null, // Dim text if read-only
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address (e.g., full address or nearby landmark)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (e.g., Home Services, Delivery)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated, e.g., cleaning, urgent)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: _listingImageFile != null
                    ? (kIsWeb // Check if running on web
                    ? Image.network(_listingImageFile!.path, fit: BoxFit.cover) // Use Image.network for web
                    : Image.file(_listingImageFile!, fit: BoxFit.cover)) // Use Image.file for other platforms
                    : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: _currentImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 50, color: Colors.grey[600]),
                    const Text('Tap to add listing image', style: TextStyle(color: Colors.grey)),
                  ],
                )),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
              text: _isEditing ? 'Update Listing' : 'Save Listing',
              onPressed: _handleSaveOrUpdate,
            ),
          ],
        ),
      ),
    );
  }
}