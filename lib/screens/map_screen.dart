// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON decoding
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // For decoding polylines

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String title;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {}; // Set to store polylines
  Position? _currentPosition; // To store the user's current location

  String _travelTime = 'Calculating...'; // To display travel time
  String _travelCost = 'Calculating...'; // To display estimated cost

  // IMPORTANT: Replace with your Google Maps Directions API Key
  // This is the same key you use for Maps SDK, but ensure Directions API is enabled for it.
  static const String GOOGLE_MAPS_API_KEY = 'AIzaSyAB3tS0U-SVSJLEHnpKKYa7wtK7cL3S2YM';

  @override
  void initState() {
    super.initState();
    _addRecipientMarker(); // Add the recipient's marker immediately
    _initializeLocationAndRoute(); // Get user's location and fetch route
  }

  // Combines location fetching and route drawing
  Future<void> _initializeLocationAndRoute() async {
    await _getCurrentLocation(); // Get user's current location first
    if (_currentPosition != null) {
      // If current location is available, fetch and draw the route
      await _getDirectionsAndDrawRoute(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(widget.latitude, widget.longitude),
      );
    }
  }

  // Callback when the Google Map is created
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Animate camera to the recipient's location initially, now that mapController is ready.
    // If _currentPosition is already available, _initializeLocationAndRoute will animate later.
    _animateCameraToLocation(LatLng(widget.latitude, widget.longitude));
  }

  // Adds a marker for the recipient's location
  void _addRecipientMarker() {
    final LatLng recipientLocation = LatLng(widget.latitude, widget.longitude);
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(widget.title), // Unique ID for the marker
          position: recipientLocation, // Position of the marker
          infoWindow: InfoWindow(title: widget.title), // Info window text
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Red marker for destination
        ),
      );
    });
  }

  // Get the user's current location and add a marker for it
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable them.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied. Please enable them in settings.')),
        );
      }
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        // Remove existing 'currentLocation' marker if any, before adding new one
        _markers.removeWhere((marker) => marker.markerId.value == 'currentLocation');
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'My Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // Different color for current location
          ),
        );
      });
      // Animate camera to user's current location after getting it,
      // only if mapController is already initialized.
      if (mapController != null) {
        _animateCameraToLocation(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting current location: ${e.toString()}')),
        );
      }
    }
  }

  // Fetches directions from Google Directions API and draws the route
  Future<void> _getDirectionsAndDrawRoute(LatLng origin, LatLng destination) async {
    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'key=$GOOGLE_MAPS_API_KEY';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final String encodedPolyline = route['overview_polyline']['points'];
          final int durationSeconds = route['legs'][0]['duration']['value']; // Duration in seconds
          final int distanceMeters = route['legs'][0]['distance']['value']; // Distance in meters

          // Decode polyline
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
          List<LatLng> polylineCoordinates = result.map((point) => LatLng(point.latitude, point.longitude)).toList();

          setState(() {
            _polylines.clear(); // Clear previous polylines
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylineCoordinates,
                color: Colors.blue, // Route line color
                width: 5,
              ),
            );

            // Update travel time
            _travelTime = _formatDuration(durationSeconds);

            // Calculate and update travel cost (example: $1 per km)
            double distanceKm = distanceMeters / 1000;
            double estimatedCost = distanceKm * 1.00; // Example: $1.00 per kilometer
            _travelCost = '\$${estimatedCost.toStringAsFixed(2)}';

            // Optionally, fit the camera to the bounds of the route
            if (mapController != null) {
              _fitRouteBounds(polylineCoordinates);
            }
          });
        } else {
          setState(() {
            _travelTime = 'No route found';
            _travelCost = 'N/A';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No route found between locations.')),
            );
          }
        }
      } else {
        setState(() {
          _travelTime = 'Error';
          _travelCost = 'Error';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch directions: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _travelTime = 'Error';
        _travelCost = 'Error';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching directions: ${e.toString()}')),
        );
      }
    }
  }

  // Helper to format duration from seconds to a readable string
  String _formatDuration(int seconds) {
    int minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = (minutes / 60).floor();
      minutes = minutes % 60;
      return '${hours} hr ${minutes} min';
    }
  }

  // Helper function to animate the camera to a given LatLng
  void _animateCameraToLocation(LatLng location) {
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 14.0, // Keep a consistent zoom level or adjust as needed
          ),
        ),
      );
    }
  }

  // Helper function to fit the camera to the bounds of the polyline
  void _fitRouteBounds(List<LatLng> polylineCoordinates) {
    if (mapController != null && polylineCoordinates.isNotEmpty) {
      LatLngBounds bounds;
      if (polylineCoordinates.length == 1) {
        bounds = LatLngBounds(
          southwest: polylineCoordinates[0],
          northeast: polylineCoordinates[0],
        );
      } else {
        double minLat = polylineCoordinates[0].latitude;
        double maxLat = polylineCoordinates[0].latitude;
        double minLon = polylineCoordinates[0].longitude;
        double maxLon = polylineCoordinates[0].longitude;

        for (var point in polylineCoordinates) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLon) minLon = point.longitude;
          if (point.longitude > maxLon) maxLon = point.longitude;
        }
        bounds = LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        );
      }

      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100), // 100 is padding
      );
    }
  }


  // Function to launch Google Maps with directions
  Future<void> _launchDirections() async {
    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot get directions: Your current location is not available.')),
        );
      }
      return;
    }

    final String originLat = _currentPosition!.latitude.toString();
    final String originLon = _currentPosition!.longitude.toString();
    final String destLat = widget.latitude.toString();
    final String destLon = widget.longitude.toString();

    // Google Maps URL scheme for directions
    // This URL will open Google Maps app with directions from origin to destination.
    final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLon&destination=$destLat,$destLon&travelmode=driving';

    final Uri uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps for directions. Please ensure Google Maps app is installed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title), // This will be "jheack jardinel's Location"
        backgroundColor: const Color(0xFF141CC9), // HANAPP Blue
        foregroundColor: Colors.white, // White text/icons
      ),
      body: Stack( // Use Stack to layer the map and the button
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated, // Callback when the map is ready
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude), // Initial map center (will be animated later)
              zoom: 14.0, // Initial zoom level
            ),
            markers: _markers, // Set of markers to display on the map
            polylines: _polylines, // Display the route polyline
            myLocationButtonEnabled: false, // Disable default My Location button
            zoomControlsEnabled: true, // Enable zoom controls
          ),

          // Top-left overlay for travel time and cost
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_bike, color: Colors.white, size: 18), // Bike icon from image
                      const SizedBox(width: 5),
                      Text(
                        _travelTime,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    _travelCost,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Position the "Directions" button at the bottom center
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _currentPosition == null ? null : _launchDirections, // Disable if current location not available
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text('Directions', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600, // Green button
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  elevation: 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
