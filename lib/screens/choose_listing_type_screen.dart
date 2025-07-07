import 'package:flutter/material.dart';
import 'package:hanapp/screens/components/custom_button.dart'; // Assuming CustomButton exists
import 'package:hanapp/utils/constants.dart' as Constants; // Your constants

class ChooseListingTypeScreen extends StatelessWidget {
  const ChooseListingTypeScreen({super.key});

  // Function to show the ASAP warning dialog
  Future<void> _showAsapWarningDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap "I Understand, Proceed"
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'WARNING!',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'ASAP listings are for onsite work only. Any task that can be done online is prohibited.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 10),
                Text(
                  'The task you are posting should also be something urgent or something you need immediate help with.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 15),
                Text(
                  'If it\'s not urgent, please post it under the Public Listing instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 15),
                Text(
                  'Doers may report you if they see you posting something inappropriate for ASAP. This may cause you to be recommended less — and worse, you could get banned from the platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Center(
              child: CustomButton(
                text: 'I Understand, Proceed',
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  // Navigate directly to the ASAP listing form
                  Navigator.of(context).pushNamed('/asap_listing_form');
                },
                color: Colors.red.shade700, // Use red color for warning
                textColor: Colors.white,
                borderRadius: 10.0,
                height: 45.0,
                width: 200, // Adjust button width as needed
              ),
            ),
          ],
        );
      },
    );
  }

  // NEW: Function to show the Public Listing warning dialog
  Future<void> _showPublicListingWarningDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap "Understood"
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'WARNING!',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Requests like... "Please help me sell", "Sell my...", "Commission for selling." or anything that asks other Doers to sell your items are not allowed on this platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 15),
                Text(
                  'Doing so may trigger the AI and the system, causing you to be recommended less and worse, you could get banned from the platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Center(
              child: CustomButton(
                text: 'Understood',
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  // Navigate to the Public Listing form after understanding the warning
                  // IMPORTANT: Ensure '/public_listing_form' is the correct route for your public listing entry form
                  Navigator.of(context).pushNamed('/public_listing_form');
                },
                color: Constants.primaryColor, // Use your primary blue color
                textColor: Colors.white,
                borderRadius: 10.0,
                height: 45.0,
                width: 150, // Adjust button width as needed
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Listing Type'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Choose what you need',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select which type of listing you want to create.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        // Show the ASAP warning dialog before navigating to ASAP form
                        _showAsapWarningDialog(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Constants.primaryColor, // Dark blue
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ASAP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'For on-demand services only. We will contact the nearest client within minutes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        // Show the Public Listing warning dialog before navigating
                        _showPublicListingWarningDialog(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Constants.primaryColor, // Dark blue
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Public Listing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Anyone can apply publicly, Anytime and Anywhere',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
