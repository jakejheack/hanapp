import 'package:flutter/material.dart';
import 'package:hanapp/models/public_listing.dart';
import 'package:hanapp/utils/public_listing_service.dart'; // Assuming this is your PublicListingService (might be ListingService)
import 'package:hanapp/models/applicantv2.dart'; // IMPORTANT: Ensure this points to your Applicant model
import 'package:hanapp/utils/auth_service.dart'; // Import AuthService to check user role
import 'package:hanapp/models/user.dart'; // Import User model
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/screens/components/custom_button.dart'; // For dialog buttons (e.g., delete)
import 'package:hanapp/screens/components/apply_modal.dart'; // Import ApplyModal
import 'package:hanapp/screens/components/custom_button_apply.dart'; // For the Apply button
import 'package:hanapp/services/listing_details_service.dart'; // Import ListingDetailsService
import 'package:hanapp/screens/view_profile_screen.dart'; // Import ViewProfileScreen
import 'package:hanapp/screens/chat_screen.dart'; // NEW: Import ChatScreen
import 'package:hanapp/services/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW: Import ChatService
import 'package:hanapp/services/application_service.dart';
import 'package:hanapp/services/notification_popup_service.dart';
import 'package:hanapp/models/notification_model.dart';

class PublicListingDetailsScreen extends StatefulWidget {
  final int listingId;

  const PublicListingDetailsScreen({super.key, required this.listingId, required int applicationId});

  @override
  State<PublicListingDetailsScreen> createState() => _PublicListingDetailsScreenState();
}

class _PublicListingDetailsScreenState extends State<PublicListingDetailsScreen> {
  PublicListing? _listing;
  List<Applicant> _applicants = [];
  bool _isLoading = true; // Overall loading state for the screen
  String? _errorMessage;
  GoogleMapController? _mapController;
  Marker? _listingMarker;
  bool _isSwitchLoading = false; // For the active/inactive switch
  User? _currentUser; // To store the current logged-in user
  bool _hasApplied = false; // To track if the current doer has applied
  bool _isApplying = false; // FIXED: Initialized to false

  final ListingDetailsService _listingDetailsService = ListingDetailsService();
  final ChatService _chatService = ChatService();
  final ApplicationService _applicationService = ApplicationService();

  @override
  void initState() {
    super.initState();
    debugPrint('PublicListingDetailsScreen: initState called for listingId: ${widget.listingId}');
    _initializeScreen();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    debugPrint('PublicListingDetailsScreen: _initializeScreen called');
    await _fetchCurrentUser();
    await _fetchListingDetailsAndApplicants();
  }

  Future<void> _incrementViewCount() async {
    if (widget.listingId != null) {
      debugPrint('PublicListingDetailsScreen: Attempting to increment view for Public listing ID: ${widget.listingId}');
      final response = await _listingDetailsService.incrementListingView(
        listingId: widget.listingId,
        listingType: 'PUBLIC',
      );
      if (!response['success']) {
        debugPrint('PublicListingDetailsScreen: Failed to increment view: ${response['message']}');
      }
    }
  }

  Future<void> _fetchCurrentUser() async {
    _currentUser = await AuthService.getUser();
    debugPrint('PublicListingDetailsScreen: Current User ID: ${_currentUser?.id}, Role: ${_currentUser?.role}');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchListingDetailsAndApplicants() async {
    debugPrint('PublicListingDetailsScreen: Fetching listing details and applicants...');
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    // IMPORTANT: Assuming ListingService (from public_listing_service.dart) or similar has getListingDetails
    final listingResponse = await ListingService().getListingDetails(widget.listingId);
    final applicantsResponse = await _applicationService.getListingApplicants(widget.listingId, 'PUBLIC');

    debugPrint('PublicListingDetailsScreen: Listing Response: $listingResponse');
    debugPrint('PublicListingDetailsScreen: Applicants Response: $applicantsResponse');

    if (listingResponse['success']) {
      _listing = listingResponse['listing'];
    } else {
      _errorMessage = listingResponse['message'] ?? 'Failed to load Public listing details.';
    }

    if (applicantsResponse['success']) {
      _applicants = applicantsResponse['applicants'];
      if (_currentUser != null && _currentUser!.role == 'doer') {
        _hasApplied = _applicants.any((applicant) {
          debugPrint('Checking applicant ID: ${applicant.doer?.id} against current user ID: ${_currentUser!.id}');
          return applicant.doer != null && applicant.doer!.id == _currentUser!.id;
        });
        debugPrint('PublicListingDetailsScreen: _hasApplied: $_hasApplied');
      } else {
        debugPrint('PublicListingDetailsScreen: Current user is not a doer, _hasApplied remains false.');
      }
      debugPrint('PublicListingDetailsScreen: Number of applicants fetched: ${_applicants.length}');
      for (var applicant in _applicants) {
        debugPrint('  Applicant ID: ${applicant.id}, Doer ID: ${applicant.doerId}, Doer Full Name: ${applicant.doer?.fullName ?? "NULL"}');
      }
    } else {
      debugPrint('PublicListingDetailsScreen: Failed to load applicants: ${applicantsResponse['message']}');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_listing != null && _listing!.latitude != null && _listing!.longitude != null) {
          _updateMapMarker(LatLng(_listing!.latitude!, _listing!.longitude!));
        }
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_listing != null && _listing!.latitude != null && _listing!.longitude != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(_listing!.latitude!, _listing!.longitude!),
        15.0,
      ));
    }
  }

  void _updateMapMarker(LatLng latLng) {
    if (mounted) {
      setState(() {
        _listingMarker = Marker(
          markerId: const MarkerId('listing_location_display'),
          position: latLng,
          infoWindow: InfoWindow(title: _listing?.title ?? 'Listing Location'),
        );
      });
    }
  }

  Future<void> _toggleListingStatus(bool newValue) async {
    if (_listing == null) return;

    if (mounted) {
      setState(() {
        _isSwitchLoading = true;
      });
    }

    // Assuming ListingService has updateListingStatus
    final response = await ListingService().updateListingStatus(
      _listing!.id,
      newValue,
    );

    if (mounted) {
      setState(() {
        _isSwitchLoading = false;
      });
    }

    if (response['success']) {
      if (mounted) {
        setState(() {
          _listing = _listing!.copyWith(isActive: newValue);
        });
      }
      _showSnackBar(response['message']);
    } else {
      _showSnackBar('Failed to update status: ${response['message']}', isError: true);
    }
  }

  Future<void> _confirmDeleteListing() async {
    if (_listing == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this Public listing? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            CustomButton(
              text: 'Delete',
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              color: Colors.red,
              textColor: Colors.white,
              borderRadius: 8.0,
              height: 40.0,
              width: 80,
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Assuming ListingService has deleteListing
      final response = await ListingService().deleteListing(_listing!.id);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (response['success']) {
        _showSnackBar(response['message']);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showSnackBar('Failed to delete listing: ${response['message']}', isError: true);
      }
    }
  }

  void _editListing() {
    if (_listing == null) return;
    Navigator.of(context).pushNamed(
      '/combined_listing_form',
      arguments: {
        'listing_id': _listing!.id,
        'listing_type': 'Public',
      },
    );
  }

  Future<void> _applyForListing() async {
    debugPrint('PublicListingDetailsScreen: _applyForListing called');
    if (_listing == null || _currentUser == null || _currentUser!.role != 'doer') {
      debugPrint('PublicListingDetailsScreen: Apply failed - User not Doer or listing/user is null.');
      _showSnackBar('You must be a Doer to apply for listings.', isError: true);
      return;
    }

    if (_hasApplied) {
      debugPrint('PublicListingDetailsScreen: Apply failed - Already applied.');
      _showSnackBar('You have already applied for this listing.', isError: true);
      return;
    }

    final String? message = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const ApplyModal();
      },
    );

    if (message != null && message.isNotEmpty) {
      debugPrint('PublicListingDetailsScreen: Apply modal returned message: $message');
      if (mounted) {
        setState(() {
          _isApplying = true;
        });
      }

      final response = await _applicationService.createApplication( // Use _applicationService instance
        listingId: _listing!.id,
        listingType: 'PUBLIC', // The value passed here
        listerId: _listing!.listerId,
        doerId: _currentUser!.id!,
        message: message,
        listingTitle: _listing!.title,
      );

      debugPrint('PublicListingDetailsScreen: ApplicationService response: $response');

      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }

      if (response['success']) {
        _showSnackBar(response['message']);
        
        // Create and show popup notification for the lister
        if (_currentUser != null && _listing != null) {
          final notification = NotificationModel(
            id: 0, // This will be set by the backend
            userId: _listing!.listerId, // Lister's ID
            senderId: _currentUser!.id!, // Doer's ID
            type: 'application',
            title: 'New Application',
            content: "${_currentUser!.fullName ?? 'A doer'} applied for your '${_listing!.title}'. Click here to view.",
            createdAt: DateTime.now(),
            isRead: false,
            associatedId: response['application_id'] ?? 0,
            relatedListingTitle: _listing!.title,
          );
          
          // Show popup notification for the lister
          NotificationPopupService().showNotification(context, notification);
        }
        
        debugPrint('PublicListingDetailsScreen: Application successful, re-fetching data...');
        _fetchListingDetailsAndApplicants();
      } else {
        _showSnackBar('Failed to apply: ${response['message']}', isError: true);
      }
    } else {
      debugPrint('PublicListingDetailsScreen: Apply modal returned null or empty message.');
    }
  }

  void _viewApplicantProfile(int doerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ViewProfileScreen(userId: doerId),
      ),
    );
  }

  // NEW: Function to initiate chat
  Future<void> _startChat({required int targetUserId, required String targetUserFullName, required int applicationIdFromBackend}) async {
    if (_currentUser == null || _listing == null || _currentUser!.id == null) {
      _showSnackBar('Error: Current user or listing data missing.', isError: true);
      return;
    }

    // Prevent self-chatting
    if (_currentUser!.id == targetUserId) {
      _showSnackBar('You cannot chat with yourself.', isError: true);
      return;
    }

    // Determine lister and doer IDs for the conversation
    // If current user is the lister of this listing, then targetUserId is the doer.
    // If current user is a doer, then _listing.listerId is the lister, and current user is the doer.
    final int conversationListerId = _listing!.listerId;
    final int conversationDoerId = (_currentUser!.id == _listing!.listerId) ? targetUserId : _currentUser!.id!;

    // Determine if the current user is the lister of *this specific listing*
    final bool currentUserIsListerOfThisListing = (_currentUser!.id == _listing!.listerId);


    setState(() {
      _isLoading = true; // Show loading while creating/getting conversation
    });

    try {
      final response = await _chatService.createOrGetConversation(
        listingId: _listing!.id,
        listingType: _listing!.listingType, // Use listing's actual type (PUBLIC/ASAP)
        listerId: conversationListerId,
        doerId: conversationDoerId,
      );

      if (response['success']) {
        final int conversationId = response['conversation_id'];
        final int? receivedApplicationId = response['application_id']; // Get application ID from backend (can be null)

        _showSnackBar('Chat initiated!');
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversationId,
                otherUserId: targetUserId, // The other person in this specific chat instance
                listingTitle: _listing!.title,
                applicationId: receivedApplicationId ?? applicationIdFromBackend, // Prioritize backend's appId, else use passed one
                isLister: currentUserIsListerOfThisListing, // <<<--- Pass this flag!
              ),
            ),
          );
        }
      } else {
        _showSnackBar('Failed to start chat: ${response['message']}', isError: true);
      }
    } catch (e) {
      // Catch specific FormatException to give a clearer message
      if (e is FormatException) {
        _showSnackBar('Server sent invalid data. Check your PHP backend for errors.', isError: true);
      } else {
        _showSnackBar('Network error: $e', isError: true);
      }
      debugPrint('Error starting chat: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
// Handles the "Connect" button specific to Doers on the Public Listing Details screen
  Future<void> _handleDoerConnectFromListing() async {
    if (_currentUser == null || _listing == null || _currentUser!.role != 'doer') {
      _showSnackBar('You must be a Doer to connect.', isError: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String warningKey = 'seenConnectWarning_doer_${_currentUser!.id}_listing_${_listing!.id}';
    final bool hasSeenWarning = prefs.getBool(warningKey) ?? false;

    if (hasSeenWarning) {
      // For a doer connecting to a lister, the 'isLister' for the chat screen will be false.
      // The `applicationIdFromBackend` will be 0 as this direct connect is not via an application yet.
      _startChat(
        targetUserId: _listing!.listerId,
        targetUserFullName: _listing!.listerFullName ?? 'Lister',
        applicationIdFromBackend: 0,
      );
    } else {
      final bool? understand = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 30),
                const SizedBox(width: 10),
                const Text('Warning!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(
                    'Sharing personal phone numbers, account details, emails, and other sensitive information is strictly prohibited on HanApp.',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Doing so may result in your account being flagged as not recommended by the platform – and worse, it could lead to a permanent ban.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Once banned, you won\'t be able to use your identity, email, or ID to sign up again. Please be cautious when sharing any information.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: Constants.textColor)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop(true);
                  await prefs.setBool(warningKey, true); // Set warning preference
                  _startChat(
                    targetUserId: _listing!.listerId,
                    targetUserFullName: _listing!.listerFullName ?? 'Lister',
                    applicationIdFromBackend: 0,
                  );
                },
                child: const Text('I Understand'),
              ),
            ],
          );
        },
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    bool showLocationSection = (_listing?.category == 'Onsite' || _listing?.category == 'Hybrid');
    bool showPaymentSection = (_listing?.price != null && _listing!.price! > 0);

    final bool isLister = (_currentUser != null && _listing != null && _currentUser!.id == _listing!.listerId);
    final bool isDoer = (_currentUser != null && _currentUser!.role == 'doer');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      )
          : _listing == null
          ? const Center(child: Text('Public Listing data not available.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _listing!.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Constants.textColor),
                  ),
                ),
                if (isLister)
                  _isSwitchLoading
                      ? const SizedBox(
                    width: 40,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Switch(
                    value: _listing!.isActive,
                    onChanged: _toggleListingStatus,
                    activeColor: Constants.primaryColor,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Constants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _listing!.category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Constants.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_listing!.price != null && _listing!.price! > 0)
              Text(
                'Php ${_listing!.price!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Constants.primaryColor),
              ),
            const SizedBox(height: 8),
            if (_listing!.locationAddress != null && _listing!.locationAddress!.isNotEmpty)
              Text(
                _listing!.locationAddress!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Text(
              '${_listing!.createdAt.toLocal().toString().split('.')[0]}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_listing!.description != null && _listing!.description!.isNotEmpty)
              Text(
                _listing!.description!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            if (_listing!.tags != null && _listing!.tags!.isNotEmpty) ...[
              Text(
                'Tags: ${_listing!.tags!}',
                style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
              ),
              const SizedBox(height: 16),
            ],
            if (isLister)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Delete',
                      onPressed: _confirmDeleteListing,
                      color: Colors.red,
                      textColor: Colors.white,
                      borderRadius: 12.0,
                      height: 45.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: 'Edit',
                      onPressed: _editListing,
                      color: Constants.primaryColor,
                      textColor: Colors.white,
                      borderRadius: 12.0,
                      height: 45.0,
                    ),
                  ),
                ],
              )
            else if (isDoer)
              _hasApplied
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'You have already applied for this job.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Constants.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
                  : CustomButtonApply(
                text: 'Apply',
                onPressed: _isApplying ? null : _applyForListing,
                color: _isApplying ? Colors.grey : Constants.primaryColor,
                textColor: Colors.white,
                borderRadius: 12.0,
                height: 50.0,
              ),
            const SizedBox(height: 24),
            if (isLister) ...[
              Text(
                'Applicants: ${_applicants.length} applied',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
              ),
              const SizedBox(height: 16),
              _applicants.isEmpty
                  ? const Center(
                child: Text(
                  'No applicants yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _applicants.length,
                itemBuilder: (context, index) {
                  final applicant = _applicants[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: (applicant.doer?.profilePictureUrl != null && applicant.doer!.profilePictureUrl!.isNotEmpty)
                                    ? NetworkImage(applicant.doer!.profilePictureUrl!)
                                    : const AssetImage('assets/dashboard_image.png') as ImageProvider,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  applicant.doer?.fullName ?? 'Unknown Doer',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            applicant.message,
                            style: const TextStyle(fontSize: 15, color: Colors.grey),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  if (applicant.doerId != null) {
                                    _viewApplicantProfile(applicant.doerId!); // Navigate to profile
                                  } else {
                                    _showSnackBar('Doer ID not available.', isError: true);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Constants.primaryColor,
                                  side: const BorderSide(color: Constants.primaryColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('View Profile'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (applicant.doerId != null && applicant.doer?.fullName != null) {
                                    _startChat(
                                      targetUserId: applicant.doerId!,
                                      targetUserFullName: applicant.doer!.fullName,
                                      applicationIdFromBackend: applicant.id!,
                                    );
                                  } else {
                                    _showSnackBar('Doer ID, name, or application ID not available for chat.', isError: true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Constants.primaryColor,
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
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
            value,
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
}
