import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hanapp/utils/location_service.dart';

class AnapListingMapScreen extends StatefulWidget {
  const AnapListingMapScreen({super.key});

  @override
  State<AnapListingMapScreen> createState() => _AnapListingMapScreenState();
}

class _AnapListingMapScreenState extends State<AnapListingMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _listingLocation;
  bool _isLoading = true;
  String _address = '';
  String _listingTitle = '';
  String _distanceTime = 'Calculating...';
  LatLng? _userCurrentLocation;

  final LocationService _locationService = LocationService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _address = args['address'] ?? '';
      _listingTitle = args['listingTitle'] ?? 'Listing Location';
      if (args['latitude'] != null && args['longitude'] != null) {
        _listingLocation = LatLng(args['latitude'], args['longitude']);
        _initializeMapAndCalculations();
      } else {
        _getListingCoordinates(_address);
      }
    } else {
      _isLoading = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing address not provided.')),
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
          const SnackBar(content: Text('Could not find coordinates for the address.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting coordinates: $e')),
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

  Future<void> _launchMapsApp() async {
    if (_listingLocation == null) {
      _showSnackBar('Listing location not available.');
      return;
    }
    final String googleMapsUrl;
    if (_userCurrentLocation != null) {
      // Corrected URL for directions from user's location to listing location
      googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=${_userCurrentLocation!.latitude},${_userCurrentLocation!.longitude}&destination=${_listingLocation!.latitude},${_listingLocation!.longitude}&travelmode=driving';
    } else {
      // Corrected URL for showing only the listing location
      googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${_listingLocation!.latitude},${_listingLocation!.longitude}';
    }

    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Could not launch map application.');
    }
  }
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _listingLocation!,
                zoom: 15.0,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('listingLocation'),
                  position: _listingLocation!,
                  infoWindow: InfoWindow(title: _listingTitle, snippet: _address),
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
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _distanceTime,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _launchMapsApp,
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34495E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}