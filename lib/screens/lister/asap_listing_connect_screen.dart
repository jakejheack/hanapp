import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart' as Constants;

class AsapListingConnectScreen extends StatelessWidget {
  final int asapListingId; // Changed to asapListingId
  final String doerName;
  final String? doerProfilePic;

  const AsapListingConnectScreen({
    super.key,
    required this.asapListingId,
    required this.doerName,
    this.doerProfilePic,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASAP Listing'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: doerProfilePic != null && doerProfilePic!.isNotEmpty
                    ? NetworkImage(doerProfilePic!)
                    : const AssetImage('assets/default_profile.png') as ImageProvider, // Default image
              ),
              const SizedBox(height: 20),
              Text(
                'Hi, this is $doerName',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Verify before you trust.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement actual connection/chat logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connecting to doer... (Placeholder)')),
                  );
                  // Example: Navigate to chat screen or home
                  Navigator.of(context).popUntil((route) => route.isFirst); // Go back to home/root
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Connect Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
