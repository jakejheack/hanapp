import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart' as Constants;

class AsapListingSearchingScreen extends StatelessWidget {
  final int asapListingId; // Changed to asapListingId

  const AsapListingSearchingScreen({super.key, required this.asapListingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASAP Listing'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Constants.primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'Searching for a doer...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please wait while we find a suitable doer for your task.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Simulate finding a doer and navigate to connect screen
                Navigator.of(context).pushReplacementNamed(
                  '/asap_listing_connect',
                  arguments: {'listing_id': asapListingId, 'doer_name': 'Jonerey', 'doer_profile_pic': 'https://placehold.co/100x100/FF5733/FFFFFF?text=JR'},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simulate Doer Found'),
            ),
          ],
        ),
      ),
    );
  }
}
