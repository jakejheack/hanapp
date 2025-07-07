import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hanapp/utils/location_service.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:url_launcher/url_launcher.dart';

class AwaitingListingScreen extends StatefulWidget {
  const AwaitingListingScreen({super.key});

  @override
  State<AwaitingListingScreen> createState() => _AwaitingListingScreenState();
}

class _AwaitingListingScreenState extends State<AwaitingListingScreen> {
  GoogleMapController? _mapController;
  LatLng? _listingLocation;
  LatLng? _userCurrentLocation;
  bool _isLoading = true;
  String _listingTitle = 'Job Location';
  String _distanceTime = 'Calculating...';
  String _listingAddress = '';

  final LocationService _locationService = LocationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _listingTitle = args['listingTitle'] ?? 'Job Location';
      _listingAddress = args['listingAddress'] ?? '';
      if (args['latitude'] != null && args['longitude'] != null) {
        _listingLocation = LatLng(args['latitude'], args['longitude']);
        _initializeMapAndCalculations();
      } else {
        _getListingCoordinates(_listingAddress);
      }
    } else {
      _isLoading = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing details not provided.')),
      );
    }
  }

  Future<void> _initializeMapAndCalculations() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Position? currentPosition = await _locationService.getCurrentLocation();
      if (currentPosition != null) {
        _userCurrentLocation = LatLng(currentPosition.latitude, currentPosition.longitude);
      }
      _calculateDistanceAndTime();
    } catch (e) {
      print("Error getting current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your current location: $e')),
      );
      _distanceTime = 'Location access denied';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getListingCoordinates(String address) async {
    try {
      LatLng? coords = await _locationService.getCoordinatesFromAddress(address);
      if (coords != null) {
        setState(() {
          _listingLocation = coords;
        });
        _initializeMapAndCalculations();
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find coordinates for the listing address.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting listing coordinates: $e')),
      );
    }
  }

  Future<void> _calculateDistanceAndTime() async {
    if (_listingLocation == null || _userCurrentLocation == null) {
      setState(() {
        _distanceTime = 'Cannot calculate (missing locations)';
      });
      return;
    }

    double distanceInMeters = _locationService.calculateDistance(
      _userCurrentLocation!,
      _listingLocation!,
    );

    String distanceText;
    if (distanceInMeters < 1000) {
      distanceText = '${distanceInMeters.round()} meters';
    } else {
      distanceText = '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }

    double timeInHours = (distanceInMeters / 1000) / 50;
    String timeText;
    if (timeInHours < 1) {
      timeText = '${(timeInHours * 60).round()} mins';
    } else {
      timeText = '${timeInHours.toStringAsFixed(1)} hours';
    }

    setState(() {
      _distanceTime = '$timeText / $distanceText';
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_listingLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_listingLocation!, 15.0));
    }
  }

  Future<void> _viewCurrentLocation() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && _mapController != null) {
        _userCurrentLocation = LatLng(position.latitude, position.longitude);
        _mapController!.animateCamera(CameraUpdate.newLatLng(_userCurrentLocation!));
        _calculateDistanceAndTime();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting current location: $e')),
      );
    }
  }

  Future<void> _launchDirections() async {
    if (_listingLocation == null || _userCurrentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot get directions without both locations.')),
      );
      return;
    }
    final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=${_userCurrentLocation!.latitude},${_userCurrentLocation!.longitude}&destination=${_listingLocation!.latitude},${_listingLocation!.longitude}&travelmode=driving';
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch map application.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_listingTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listingLocation == null
          ? const Center(child: Text('Location not found or error occurred.'))
          : Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _listingLocation!,
                    zoom: 15.0,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('listingLocation'),
                      position: _listingLocation!,
                      infoWindow: InfoWindow(title: _listingTitle, snippet: _listingAddress),
                    ),
                    if (_userCurrentLocation != null)
                      Marker(
                        markerId: const MarkerId('userCurrentLocation'),
                        position: _userCurrentLocation!,
                        infoWindow: const InfoWindow(title: 'Your Location'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      ),
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton.extended(
                    onPressed: _viewCurrentLocation,
                    label: const Text('View Current Location'),
                    icon: const Icon(Icons.my_location),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF34495E),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _distanceTime,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CustomButton(
                  text: 'Get Directions',
                  onPressed: _launchDirections,
                  icon: Icons.directions,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Confirm Job',
                  onPressed: () {
                    // This should likely navigate to the ConfirmJobScreen
                    // or trigger a confirmation flow if the current user is the Lister
                    // For now, just a placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Confirm Job logic here.')),
                    );
                  },
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}