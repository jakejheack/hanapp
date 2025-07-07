import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hanapp/utils/location_service.dart';

class SelectLocationOnMapScreen extends StatefulWidget {
  const SelectLocationOnMapScreen({super.key});

  @override
  State<SelectLocationOnMapScreen> createState() => _SelectLocationOnMapScreenState();
}

class _SelectLocationOnMapScreenState extends State<SelectLocationOnMapScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(14.5995, 120.9842); // Default to Manila
  String _selectedAddress = 'Loading address...';
  bool _isLoading = true;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initializeLocationAndMap();
  }

  Future<void> _initializeLocationAndMap() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null) {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      }
      await _getAddressFromLatLng(_selectedLocation);
    } catch (e) {
      print("Error initializing location: $e");
      await _getAddressFromLatLng(_selectedLocation);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation));
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    setState(() {
      _selectedAddress = 'Fetching address...';
    });
    String? address = await _locationService.getAddressFromCoordinates(latLng.latitude, latLng.longitude);
    setState(() {
      _selectedAddress = address ?? 'Address not found';
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation));
  }

  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
  }

  Future<void> _onCameraIdle() async {
    await _getAddressFromLatLng(_selectedLocation);
  }

  void _confirmLocation() {
    Navigator.of(context).pop({
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 14.0,
            ),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
          ),
          Center(
            child: Icon(Icons.location_pin, size: 50, color: Theme.of(context).primaryColor),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                      _selectedAddress,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _confirmLocation,
                      child: const Text('Confirm Location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}