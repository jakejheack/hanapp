import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // Requires google_maps_flutter package
import 'package:hanapp/services/api_service.dart'; // Assuming this exists
import 'package:hanapp/screens/doer/asap_searching_doer_screen.dart'; // Next screen in flow
import 'package:hanapp/utils/constants.dart';

import '../../utils/constants.dart' as Constants; // For colors and padding

class AsapListingMapScreen extends StatelessWidget {
  final Map<String, dynamic> listingData;

  const AsapListingMapScreen({super.key, required this.listingData});

  void _payAndConfirm(BuildContext context) async {
    // Simulate API call to create listing
    try {
      // In a real app, you would uncomment this and call your API service:
      // await ApiService().postAsapListing(listingData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing posted successfully!')),
        );
        // Navigate to searching for a doer screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AsapSearchingDoerScreen(listingData: listingData)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post listing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asap Listing'), // Title from image
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Placeholder for Google Map. You'd use GoogleMap widget here.
                Container(
                  color: Colors.grey[200], // Placeholder map background
                  child: const Center(
                    child: Text('Map View Placeholder', style: TextStyle(fontSize: 20, color: Colors.grey)),
                  ),
                ),
                // Overlayed card with listing details and travel time
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listingData['title'] as String,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${listingData['price'].toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 16, color: Colors.green),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  // This image asset needs to be added to your pubspec.yaml and assets folder
                                  // For now, using a placeholder icon if the asset is not available.
                                  Image.asset(
                                    'assets/car_icon.png', // Placeholder image for car
                                    width: 40,
                                    height: 40,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.directions_car, size: 40, color: Colors.blue);
                                    },
                                  ),
                                  const Text('-23 min', style: TextStyle(fontWeight: FontWeight.bold)), // Example from image
                                  const Text('3 km', style: TextStyle(color: Colors.grey)), // Example from image
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            listingData['description'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _payAndConfirm(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.primaryColor, // Blue button from image
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Pay & Confirm'), // Button text from image
                          ),
                        ],
                      ),
                    ),
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
