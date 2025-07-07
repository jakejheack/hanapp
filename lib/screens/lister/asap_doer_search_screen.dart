import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/models/user.dart';
import 'package:hanapp/models/asap_listing.dart';
import 'package:hanapp/services/asap_service.dart';
import 'package:hanapp/utils/asap_listing_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class AsapDoerSearchScreen extends StatefulWidget {
  final int listingId;
  final double listingLatitude;
  final double listingLongitude;
  final String preferredDoerGender;
  final double maxDistance;

  const AsapDoerSearchScreen({
    super.key,
    required this.listingId,
    required this.listingLatitude,
    required this.listingLongitude,
    required this.preferredDoerGender,
    required this.maxDistance,
  });

  @override
  State<AsapDoerSearchScreen> createState() => _AsapDoerSearchScreenState();
}

class _AsapDoerSearchScreenState extends State<AsapDoerSearchScreen> {
  final AsapService _asapService = AsapService();
  final AsapListingService _asapListingService = AsapListingService();
  List<User> _availableDoers = [];
  AsapListing? _listing;
  bool _isLoading = true;
  bool _isSearching = true;
  String? _errorMessage;
  
  // Map related variables
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _listerLocation;
  LatLng? _doerLocation;

  // Filter variables
  double _maxDistance = 5.0;
  String _preferredDoerGender = 'Any';

  @override
  void initState() {
    super.initState();
    // Initialize filter variables with widget values
    _maxDistance = widget.maxDistance;
    _preferredDoerGender = widget.preferredDoerGender;
    
    _initializeMap();
    _fetchListingDetails();
    _startSearching();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeMap() {
    _listerLocation = LatLng(widget.listingLatitude, widget.listingLongitude);
    _updateMarkers();
  }

  void _updateMarkers() {
    Set<Marker> markers = {};
    
    // Add lister marker
    if (_listerLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('lister_location'),
        position: _listerLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Lister Location',
          snippet: 'Your location',
        ),
      ));
    }
    
    // Add doer marker if available
    if (_doerLocation != null && _availableDoers.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('doer_location'),
        position: _doerLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Doer Location',
          snippet: '${_availableDoers.first.fullName}',
        ),
      ));
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _updateRoute() {
    if (_listerLocation != null && _doerLocation != null) {
      // Create a simple straight line route (in a real app, you'd use Google Directions API)
      Set<Polyline> polylines = {};
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [_doerLocation!, _listerLocation!],
        color: Colors.blue,
        width: 3,
      ));
      
      setState(() {
        _polylines = polylines;
      });
      
      // Fit bounds to show both markers
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (_mapController != null && _listerLocation != null && _doerLocation != null) {
      double minLat = _listerLocation!.latitude < _doerLocation!.latitude 
          ? _listerLocation!.latitude 
          : _doerLocation!.latitude;
      double maxLat = _listerLocation!.latitude > _doerLocation!.latitude 
          ? _listerLocation!.latitude 
          : _doerLocation!.latitude;
      double minLng = _listerLocation!.longitude < _doerLocation!.longitude 
          ? _listerLocation!.longitude 
          : _doerLocation!.longitude;
      double maxLng = _listerLocation!.longitude > _doerLocation!.longitude 
          ? _listerLocation!.longitude 
          : _doerLocation!.longitude;
      
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        50.0,
      ));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_listerLocation != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(_listerLocation!, 15.0));
    }
  }

  Future<void> _fetchListingDetails() async {
    try {
      final response = await _asapListingService.getAsapListingDetails(widget.listingId);
      if (response['success'] && mounted) {
        setState(() {
          _listing = response['listing'];
        });
      }
    } catch (e) {
      print('Error fetching listing details: $e');
    }
  }

  Future<void> _startSearching() async {
    // Simulate searching time
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      setState(() {
        _isSearching = false;
      });
      _searchDoers();
    }
  }

  // Method to refresh search results (called by rescan button)
  Future<void> _searchForDoers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _searchDoers();
  }

  Future<void> _searchDoers() async {
    try {
      final currentUser = await AuthService.getUser();
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      print('Doer Search: Starting search for nearest and available doers...');
      print('  listingId: ${widget.listingId}');
      print('  listingLatitude: ${widget.listingLatitude}');
      print('  listingLongitude: ${widget.listingLongitude}');
      print('  preferredDoerGender: $_preferredDoerGender');
      print('  maxDistance: ${_maxDistance}km');

      final response = await _asapService.searchDoers(
        listingId: widget.listingId,
        listerLatitude: widget.listingLatitude,
        listerLongitude: widget.listingLongitude,
        preferredDoerGender: _preferredDoerGender,
        maxDistance: _maxDistance,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response['success']) {
            print('Doer Search: Backend response success, parsing doers...');
            print('Doer Search: Raw doers data: ${response['doers']}');
            
            _availableDoers = (response['doers'] as List)
                .map((doerData) {
                  print('Doer Search: Parsing doer data: $doerData');
                  return User.fromJson(doerData);
                })
                .toList();
            print('Doer Search: Successfully parsed ${_availableDoers.length} doers');
            
            // Update map with doer location if found
            if (_availableDoers.isNotEmpty) {
              _updateMapWithDoer();
            }
          } else {
            _errorMessage = response['message'] ?? 'Failed to search for doers';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error searching for doers: $e';
        });
      }
    }
  }

  void _updateMapWithDoer() {
    if (_availableDoers.isNotEmpty) {
      // Use the first doer's location (you might want to use the nearest one)
      final doer = _availableDoers.first;
      if (doer.latitude != null && doer.longitude != null) {
        _doerLocation = LatLng(doer.latitude!, doer.longitude!);
        _updateMarkers();
        _updateRoute();
      }
    }
  }

  void _selectDoer(User doer) {
    print('Doer Selection: Showing selection dialog for doer: ${doer.fullName}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Doer'),
        content: Text('Are you sure you want to select ${doer.fullName} for this task?'),
        actions: [
          TextButton(
            onPressed: () {
              print('Doer Selection: User cancelled selection');
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              print('Doer Selection: User confirmed selection');
              Navigator.of(context).pop();
              _confirmDoerSelection(doer);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDoerSelection(User doer) async {
    print('Doer Selection: Starting doer selection process...');
    print('Doer Selection: Selected doer ID: ${doer.id}');
    print('Doer Selection: Selected doer name: ${doer.fullName}');
    print('Doer Selection: Listing ID: ${widget.listingId}');
    
    try {
      final currentUser = await AuthService.getUser();
      if (currentUser == null) {
        print('Doer Selection: ERROR - Current user is null');
        return;
      }
      
      print('Doer Selection: Current user ID: ${currentUser.id}');
      print('Doer Selection: Current user name: ${currentUser.fullName}');

      print('Doer Selection: Calling selectDoer API...');
      final response = await _asapService.selectDoer(
        listingId: widget.listingId,
        doerId: doer.id!,
        listerId: currentUser.id!,
      );

      print('Doer Selection: API response received:');
      print('Doer Selection: Response success: ${response['success']}');
      print('Doer Selection: Response message: ${response['message']}');
      print('Doer Selection: Full response: $response');

      if (response['success']) {
        print('Doer Selection: SUCCESS - Doer selected successfully');
        print('Doer Selection: Application ID: ${response['application_id']}');
        print('Doer Selection: Conversation ID: ${response['conversation_id']}');
        
        if (mounted) {
          print('Doer Selection: Navigating to doer connect screen...');
          Navigator.of(context).pushReplacementNamed(
            '/asap_doer_connect',
            arguments: {
              'listing_id': widget.listingId,
              'listing_title': response['listing']?['title'] ?? 'ASAP Task',
              'doer_name': doer.fullName,
              'doer_profile_pic': doer.profilePictureUrl,
              'doer_id': doer.id,
              'application_id': response['application_id'],
              'conversation_id': response['conversation_id'],
            },
          );
          print('Doer Selection: Navigation completed');
        }
      } else {
        print('Doer Selection: ERROR - Failed to select doer');
        print('Doer Selection: Error message: ${response['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to select doer')),
          );
        }
      }
    } catch (e) {
      print('Doer Selection: EXCEPTION - Error selecting doer: $e');
      print('Doer Selection: Exception type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting doer: $e')),
        );
      }
    }
  }

  void _convertToPublic() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Public Listing'),
        content: const Text(
          'No doers are accepting your ASAP offer. Would you like to make it publicly available?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No, Exit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmConvertToPublic();
            },
            child: const Text('Yes, Make Public'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmConvertToPublic() async {
    try {
      final currentUser = await AuthService.getUser();
      if (currentUser == null) return;

      final response = await _asapService.convertToPublic(
        listingId: widget.listingId,
        listerId: currentUser.id!,
      );

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Converted to public listing')),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to convert to public')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting to public: $e')),
        );
      }
    }
  }

  // Working map widget
  Widget _buildMapWidget() {
    if (_listerLocation == null) {
      return Container(
        height: 180,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade200,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _listerLocation!,
            zoom: 15.0,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  // Add a placeholder for the listing details (in a real app, fetch the details)
  Widget _buildListingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Working map widget
        _buildMapWidget(),
        // Listing details (using actual data)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _listing?.title ?? 'ASAP Listing',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 4),
              if (_listing?.description != null && _listing!.description!.isNotEmpty) ...[
                Text(
                  'Description: ${_listing!.description}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
                const SizedBox(height: 2),
              ],
              if (_listing?.locationAddress != null) ...[
                Text(
                  'Address: ${_listing!.locationAddress}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
                const SizedBox(height: 2),
              ],
              if (_listing?.price != null) ...[
                Text(
                  'Price: Php ${_listing!.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
                const SizedBox(height: 2),
              ],
              if (_listing?.preferredDoerGender != null && _listing!.preferredDoerGender != 'Any') ...[
                Text(
                  'Preferred: ${_listing!.preferredDoerGender}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Carousel reminders widget
  Widget _buildRemindersCarousel() {
    final reminders = [
      {
        'icon': Icons.verified_user,
        'title': 'Verify before you trust',
        'desc': 'Check reviews, ratings, and identity verifications before meeting. Cancel immediately if something feels off.'
      },
      {
        'icon': Icons.payment,
        'title': 'Pay only via HanApp',
        'desc': 'Never pay outside the app. HanApp protects your payments.'
      },
      {
        'icon': Icons.report,
        'title': 'Report suspicious activity',
        'desc': 'Help keep the community safe by reporting any harassment or illegal requests.'
      },
    ];
    return SizedBox(
      height: 140,
      child: PageView.builder(
        itemCount: reminders.length,
        controller: PageController(viewportFraction: 0.85),
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Icon(reminder['icon'] as IconData, size: 40, color: Constants.primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(reminder['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(reminder['desc'] as String, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // List of available doers
  Widget _buildDoersListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.people, color: Constants.primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '${_availableDoers.length} Available Doer${_availableDoers.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _availableDoers.length,
            itemBuilder: (context, index) {
              return _buildDoerCard(_availableDoers[index]);
            },
          ),
        ),
      ],
    );
  }

  // Individual doer card
  Widget _buildDoerCard(User doer) {
    final distance = _calculateDistance(doer.latitude ?? 0, doer.longitude ?? 0);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: doer.profilePictureUrl != null
                      ? CachedNetworkImageProvider(doer.profilePictureUrl!)
                      : null,
                  child: doer.profilePictureUrl == null
                      ? Text(
                          doer.fullName.isNotEmpty ? doer.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doer.fullName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (doer.isVerified)
                            const Icon(Icons.verified, color: Colors.blue, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${doer.averageRating?.toStringAsFixed(1) ?? '0.0'} (${doer.totalReviews ?? 0} reviews)',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${distance.toStringAsFixed(1)}km away • ${doer.addressDetails?.split(',').first.trim() ?? 'Unknown location'}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.green, size: 8),
                                const SizedBox(width: 4),
                                Text(
                                  'Available Now',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _selectDoer(doer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Connect Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Doer found card (show only the first doer for now)
  Widget _buildDoerFoundCard(User doer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: ImageUtils.createProfileImageProvider(doer.profilePictureUrl),
              child: doer.profilePictureUrl == null
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(height: 16),
            Text('Hi, this is ${doer.fullName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your list was accepted', style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 18),
                const SizedBox(width: 4),
                Text(doer.addressDetails ?? 'Unknown', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(5, (i) => Icon(
                  i < (doer.averageRating ?? 0).round()
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                )),
                const SizedBox(width: 6),
                Text('${(doer.averageRating ?? 0.0).toStringAsFixed(1)}/5.0', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            // Show distance if available (this would need to be added to the User model or passed separately)
            if (doer.latitude != null && doer.longitude != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_walk, color: Colors.blue, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${_calculateDistance(doer.latitude!, doer.longitude!).toStringAsFixed(1)} km away',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _selectDoer(doer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Connect Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to calculate distance between two points
  double _calculateDistance(double lat1, double lon1) {
    if (_listerLocation == null) return 0.0;
    
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = _listerLocation!.latitude * (math.pi / 180);
    double lat2Rad = lat1 * (math.pi / 180);
    double deltaLat = (lat1 - _listerLocation!.latitude) * (math.pi / 180);
    double deltaLon = (lon1 - _listerLocation!.longitude) * (math.pi / 180);
    
    double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Enhanced spinner with pulsing effect and rotating dots
  Widget _buildEnhancedSpinner() {
    return const _EnhancedSpinnerWidget();
  }

  // Typing effect text widget
  Widget _buildTypingText() {
    return _TypingTextWidget(
      text: 'Searching for a doer',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Constants.textColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildListingHeader(),
          Expanded(
            child: _isLoading || _isSearching
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      _buildEnhancedSpinner(),
                      const SizedBox(height: 32),
                      _buildTypingText(),
                      const SizedBox(height: 24),
                      _buildRemindersCarousel(),
                    ],
                  )
                : _errorMessage != null
                    ? _buildErrorView()
                    : (_availableDoers.isNotEmpty
                        ? _buildDoersListView()
                        : _buildNoDoersView()),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _searchDoers,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDoersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Doers Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No doers are accepting your ASAP offer at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _convertToPublic,
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Convert to Public Listing'),
            ),
            const SizedBox(height: 16),
            // Combined rescan and filter button
            ElevatedButton.icon(
              onPressed: _showFilterAndRescanDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Rescan & Filter'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Available Doers'),
      backgroundColor: Constants.primaryColor,
      foregroundColor: Colors.white,
    );
  }

  // Show filter dialog for doer search
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Doers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distance filter
            ListTile(
              title: const Text('Maximum Distance'),
              subtitle: Text('${_maxDistance.toInt()} km'),
              trailing: DropdownButton<double>(
                value: _maxDistance,
                items: [1.0, 2.0, 3.0, 4.0, 5.0, 10.0].map((distance) {
                  return DropdownMenuItem(
                    value: distance,
                    child: Text('${distance.toInt()} km'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _maxDistance = value;
                    });
                    Navigator.of(context).pop();
                    _searchForDoers();
                  }
                },
              ),
            ),
            // Gender filter
            ListTile(
              title: const Text('Preferred Gender'),
              subtitle: Text(_preferredDoerGender),
              trailing: DropdownButton<String>(
                value: _preferredDoerGender,
                items: ['Any', 'Male', 'Female'].map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _preferredDoerGender = value;
                    });
                    Navigator.of(context).pop();
                    _searchForDoers();
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchForDoers();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // Show combined filter and rescan dialog with slider up to 100km
  void _showFilterAndRescanDialog() {
    double tempDistance = _maxDistance;
    String tempGender = _preferredDoerGender;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rescan & Filter Doers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Distance slider (up to 100km)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maximum Distance: ${tempDistance.toInt()} km',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: tempDistance,
                    min: 1.0,
                    max: 100.0,
                    divisions: 99, // Creates 100 steps (1km to 100km)
                    label: '${tempDistance.toInt()} km',
                    onChanged: (value) {
                      setDialogState(() {
                        tempDistance = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              // Gender filter
              ListTile(
                title: const Text('Preferred Gender'),
                subtitle: Text(tempGender),
                trailing: DropdownButton<String>(
                  value: tempGender,
                  items: ['Any', 'Male', 'Female'].map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        tempGender = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _maxDistance = tempDistance;
                  _preferredDoerGender = tempGender;
                });
                Navigator.of(context).pop();
                _searchForDoers();
              },
              child: const Text('Rescan & Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced spinner widget with multiple animations
class _EnhancedSpinnerWidget extends StatefulWidget {
  const _EnhancedSpinnerWidget();

  @override
  State<_EnhancedSpinnerWidget> createState() => _EnhancedSpinnerWidgetState();
}

class _EnhancedSpinnerWidgetState extends State<_EnhancedSpinnerWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _dotsController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for outer circle
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation for inner spinner
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_rotationController);

    // Dots animation
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start animations
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _dotsController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing circle
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Constants.primaryColor.withOpacity(0.1),
                    border: Border.all(
                      color: Constants.primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),

          // Rotating dots around the circle
          AnimatedBuilder(
            animation: _dotsController,
            builder: (context, child) {
              return SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  children: List.generate(8, (index) {
                    final angle = (index * math.pi * 2 / 8) + (_dotsController.value * math.pi * 2);
                    final x = 35 + 25 * math.cos(angle);
                    final y = 35 + 25 * math.sin(angle);

                    return Positioned(
                      left: x - 3,
                      top: y - 3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Constants.primaryColor.withOpacity(
                            0.3 + 0.7 * math.sin(_dotsController.value * math.pi * 2 + index * math.pi / 4).abs(),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          // Inner rotating spinner with gradient
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * math.pi * 2,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Constants.primaryColor,
                        Constants.primaryColor.withOpacity(0.1),
                        Constants.primaryColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Center search icon
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Constants.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Constants.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.search,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Typing text effect widget with two phases
class _TypingTextWidget extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;

  const _TypingTextWidget({
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 100),
  });

  @override
  State<_TypingTextWidget> createState() => _TypingTextWidgetState();
}

class _TypingTextWidgetState extends State<_TypingTextWidget> {
  String _displayedText = '';
  Timer? _typingTimer;
  Timer? _dotsTimer;
  int _currentIndex = 0;
  bool _isMainTextComplete = false;
  int _dotsCount = 0;

  @override
  void initState() {
    super.initState();
    _startMainTextTyping();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  void _startMainTextTyping() {
    _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentIndex < widget.text.length) {
          _displayedText = widget.text.substring(0, _currentIndex + 1);
          _currentIndex++;
        } else {
          // Main text is complete, start dots animation
          _isMainTextComplete = true;
          timer.cancel();
          _startDotsAnimation();
        }
      });
    });
  }

  void _startDotsAnimation() {
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _dotsCount = (_dotsCount + 1) % 4; // Cycle through 0, 1, 2, 3
      });
    });
  }

  String _getDotsText() {
    switch (_dotsCount) {
      case 0:
        return '';
      case 1:
        return '.';
      case 2:
        return '..';
      case 3:
        return '...';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _displayedText,
          style: widget.style,
        ),
        if (_isMainTextComplete) ...[
          // Show animated dots after main text is complete
          Text(
            _getDotsText(),
            style: widget.style.copyWith(
              color: widget.style.color,
            ),
          ),
        ],
      ],
    );
  }
}