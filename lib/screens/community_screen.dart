// lib/screens/community_screen.dart
import 'package:flutter/material.dart';
import '../widgets/community_card.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect with HanApp!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join our community on your favorite platforms. Tap a card to connect!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                // Dynamic community card list from backend
                SizedBox(
                  height: 500, // Adjust as needed for your layout
                  child: CommunityCardList(
                    apiUrl: 'https://autosell.io/api/community/get_cms_socials.php',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}