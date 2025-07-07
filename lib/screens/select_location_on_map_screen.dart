// lib/screens/select_location_on_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; // For reverse geocoding
import 'package:geolocator/geolocator.dart'; // To get initial current location

class SelectLocationOnMapScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const SelectLocationOnMapScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<SelectLocationOnMapScreen> createState() => _SelectLocationOnMapScreenState();
}

class _SelectLocationOnMapScreenState extends State<SelectLocationOnMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = "Tap on map or drag marker to select location";
  Set<Marker> _markers = {};
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initializeMapLocation();
  }

  Future<void> _initializeMapLocation() async {
    LatLng initialTarget;
    String initialInfo;

    // Try to use initial values passed from EditProfileScreen
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      initialTarget = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedLocation = initialTarget;
      initialInfo = widget.initialAddress ?? "Selected Location";
      _selectedAddress = initialInfo;
      _addMarker(initialTarget, initialInfo);
      _isLoadingLocation = false;
      setState(() {});
      return;
    }

    // If no initial values, try to get current device location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Trying default location.')),
          );
        }
        initialTarget = const LatLng(14.5995, 120.9842); // Default to Manila, Philippines
        initialInfo = "Default Location (Manila)";
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location permissions denied. Trying default location.')),
              );
            }
            initialTarget = const LatLng(14.5995, 120.9842); // Default to Manila, Philippines
            initialInfo = "Default Location (Manila)";
          } else {
            Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            initialTarget = LatLng(position.latitude, position.longitude);
            _selectedLocation = initialTarget; // Set selected location to current
            await _reverseGeocode(initialTarget); // Get address for current location
            initialInfo = _selectedAddress; // Update initial info with actual address
          }
        } else if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions permanently denied. Trying default location.')),
            );
          }
          initialTarget = const LatLng(14.5995, 120.9842); // Default to Manila, Philippines
          initialInfo = "Default Location (Manila)";
        } else {
          Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          initialTarget = LatLng(position.latitude, position.longitude);
          _selectedLocation = initialTarget; // Set selected location to current
          await _reverseGeocode(initialTarget); // Get address for current location
          initialInfo = _selectedAddress; // Update initial info with actual address
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting current location: ${e.toString()}. Using default.')),
        );
      }
      initialTarget = const LatLng(14.5995, 120.9842); // Fallback to Manila
      initialInfo = "Default Location (Manila)";
    }

    // Add marker for the determined initial location
    _addMarker(initialTarget, initialInfo);
    _isLoadingLocation = false;
    setState(() {}); // Rebuild to show map and initial marker
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
      );
    } else {
      // If no selected location yet, animate to the initial target after map is created
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_markers.first.position, 15.0),
      );
    }
  }

  void _addMarker(LatLng position, String info) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selectedLocation'),
        position: position,
        infoWindow: InfoWindow(title: info),
        draggable: true,
        onDragEnd: (newPosition) {
          _selectedLocation = newPosition;
          _reverseGeocode(newPosition);
        },
      ),
    );
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _addMarker(latLng, "Selected Location");
      _reverseGeocode(latLng);
    });
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
        setState(() {
          _selectedAddress = address;
          _addMarker(location, address); // Update marker info window
        });
      } else {
        setState(() {
          _selectedAddress = 'No address found for this location.';
          _addMarker(location, _selectedAddress);
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Error getting address: ${e.toString()}';
        _addMarker(location, _selectedAddress);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting address: ${e.toString()}')),
        );
      }
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null && _selectedAddress.isNotEmpty) {
      Navigator.of(context).pop({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _selectedAddress,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: const Color(0xFF141CC9),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? const LatLng(14.5995, 120.9842), // Default to Manila if no initial
              zoom: 15.0,
            ),
            markers: _markers,
            onTap: _onMapTap, // Allow tapping to select location
            myLocationButtonEnabled: true, // Show My Location button
            zoomControlsEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _selectedAddress,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _selectedLocation != null ? _confirmLocation : null,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Confirm Location', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
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
