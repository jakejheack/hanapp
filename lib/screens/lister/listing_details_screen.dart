import 'package:flutter/material.dart';
import 'package:hanapp/utils/listing_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/listing.dart';
import 'package:hanapp/models/applicant.dart';
import 'package:hanapp/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/models/listing_application.dart';
import 'package:hanapp/services/api_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

class ListingDetailsScreen extends StatefulWidget {
  const ListingDetailsScreen({super.key});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  final ListingService _listingService = ListingService();
  final AuthService _authService = AuthService();
  Listing? _listing;
  List<Applicant> _applicants = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isCompleting = false;
  User? _currentUser; // To check if current user is the lister or doer

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final listingId = ModalRoute.of(context)!.settings.arguments as int;
    _fetchListingDetails(listingId);
    _fetchApplicants(listingId);
  }

  Future<void> _fetchListingDetails(int listingId) async {
    setState(() {
      _isLoading = true;
    });
    final response = await _listingService.getListingDetails(listingId);
    setState(() {
      _isLoading = false;
      if (response['success']) {
        _listing = response['listing'];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load listing details: ${response['message']}')),
        );
      }
    });
  }

  Future<void> _fetchApplicants(int listingId) async {
    final response = await _listingService.getApplicants(listingId);
    if (response['success']) {
      setState(() {
        _applicants = response['applicants'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load applicants: ${response['message']}')),
      );
    }
  }

  Future<void> _deleteListing() async {
    if (_listing == null || _currentUser == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this listing?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
      });
      final response = await _listingService.deleteListing(_listing!.id, _currentUser!.id);
      setState(() {
        _isDeleting = false;
      });

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
        Navigator.of(context).pop(); // Go back to job listings
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete listing: ${response['message']}')),
        );
      }
    }
  }

  Future<void> _completeListing() async {
    if (_listing == null || _currentUser == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Completion'),
          content: const Text('Are you sure you want to mark this listing as complete?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Complete', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isCompleting = true;
      });
      final response = await _listingService.completeListing(_listing!.id, _currentUser!.id);
      setState(() {
        _isCompleting = false;
      });

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
        _fetchListingDetails(_listing!.id); // Refresh details to show new status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete listing: ${response['message']}')),
        );
      }
    }
  }

  Future<void> _applyToListing() async {
    if (_listing == null || _currentUser == null) return;

    // Show input dialog for message
    String? message = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController messageController = TextEditingController();
        return AlertDialog(
          title: const Text('Apply to Listing'),
          content: TextField(
            controller: messageController,
            decoration: const InputDecoration(
              hintText: 'Enter your message to the lister...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(messageController.text),
              child: const Text('Submit Application'),
            ),
          ],
        );
      },
    );

    if (message != null && message.isNotEmpty) {
      setState(() {
        _isLoading = true; // Use general loading for application
      });

      final response = await _listingService.applyToListing(
        _listing!.id,
        _currentUser!.id,
        message: message, // Pass the message
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'])),
        );
        _fetchApplicants(_listing!.id); // Refresh applicants list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply: ${response['message']}')),
        );
      }
    } else if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application cancelled or message was empty.')),
      );
    }
  }

  // Helper function to format date and time as "April 26, 2025 12 hours ago"
  String _formatDateTime(DateTime dateTime) {
    final String formattedDate = DateFormat('MMMM d,yyyy').format(dateTime);
    final Duration diff = DateTime.now().difference(dateTime);

    String timeAgo;
    if (diff.inDays > 0) {
      timeAgo = '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      timeAgo = '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      timeAgo = '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      timeAgo = 'just now';
    }
    return '$formattedDate $timeAgo';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _listing == null || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isLister = _currentUser!.id == _listing!.listerId;
    final bool isActive = _listing!.status == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
        backgroundColor: const Color(0xFF141CC9), // HANAPP Blue
        foregroundColor: Colors.white, // White text/icons
        elevation: 0,
        actions: [
          if (isLister) // Only show status toggle for the lister
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Text(
                    isActive ? 'Active' : 'Completed',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Switch(
                    value: isActive,
                    onChanged: (bool value) {
                      if (!value) { // Only allow switching to 'completed'
                        _completeListing();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot re-open listing directly. Contact support if needed.')),
                        );
                      }
                    },
                    activeColor: Colors.greenAccent,
                    inactiveTrackColor: Colors.redAccent,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Listing Image
            if (_listing!.imageUrl != null && _listing!.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: _listing!.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 100),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image, size: 100, color: Colors.grey),
              ),
            const SizedBox(height: 16),

            // Title and Price
            Text(
              _listing!.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '₱${_listing!.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Location and Date/Time
            Text(
              '${_listing!.address} · ${_formatDateTime(_listing!.createdAt)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              _listing!.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Tags
            if (_listing!.tags != null && _listing!.tags!.isNotEmpty)
              Wrap(
                spacing: 8.0, // gap between adjacent chips
                runSpacing: 4.0, // gap between lines
                children: _listing!.tags!.split(',').map((tag) => Chip(
                  label: Text(tag.trim()),
                  backgroundColor: Colors.blue.shade50,
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                )).toList(),
              ),
            const SizedBox(height: 24),

            if (isLister) ...[
              // Lister-specific buttons: Delete and Edit
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _isDeleting
                        ? const Center(child: CircularProgressIndicator())
                        : CustomButton(
                      text: 'Delete',
                      onPressed: _deleteListing,
                      color: Colors.red,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: 'Edit',
                      onPressed: () {
                        // Pass the current listing object to the edit screen
                        Navigator.of(context).pushNamed('/enter_listing_details', arguments: _listing);
                      },
                      color: Colors.blueGrey,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Applicants Section for Lister
              Text(
                'Applicants: ${_applicants.length} applied.',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _applicants.isEmpty
                  ? const Text('No applicants yet.')
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _applicants.length,
                itemBuilder: (context, index) {
                  final applicant = _applicants[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: ImageUtils.createProfileImageProvider(applicant.profilePictureUrl),
                                child: (applicant.profilePictureUrl == null || applicant.profilePictureUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      applicant.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    // Placeholder for stars/recommendation
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < (_currentUser?.averageRating ?? 0).round() ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (applicant.message != null && applicant.message!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              applicant.message!,
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  // TODO: Navigate to View Profile Screen for applicant
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Viewing profile for ${applicant.fullName}')),
                                  );
                                },
                                child: const Text('View Profile'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // Navigate to chat screen with this applicant
                                  if (_currentUser != null && _listing != null) {
                                    Navigator.of(context).pushNamed(
                                      '/unified_chat_screen', // Navigate to the unified chat screen
                                      arguments: {
                                        'recipientName': applicant.fullName,
                                        'recipientId': applicant.applicantId,
                                        'listingId': _listing!.id,
                                        'applicationId': applicant.applicationId, // Pass application ID
                                        'isLister': true, // Indicate that the current user is the lister
                                      },
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF141CC9), // HANAPP Blue
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Connect'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ] else if (_currentUser!.role == 'doer') ...[ // Changed from 'doer' to 'Owner' for consistency
              // Owner-specific action
              CustomButton(
                text: 'Apply to this Listing',
                onPressed: _applyToListing,
                color: Colors.blueAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}