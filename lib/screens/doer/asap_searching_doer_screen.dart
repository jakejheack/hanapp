import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart';

import '../../utils/constants.dart' as Constants; // For colors and padding
import '../../services/asap_service.dart';

class AsapSearchingDoerScreen extends StatefulWidget {
  final Map<String, dynamic> listingData;

  const AsapSearchingDoerScreen({super.key, required this.listingData});

  @override
  State<AsapSearchingDoerScreen> createState() => _AsapSearchingDoerScreenState();
}

class _AsapSearchingDoerScreenState extends State<AsapSearchingDoerScreen> {
  double? _manualRadius;

  @override
  void initState() {
    super.initState();
    // Simulate searching for a doer
    _startSearching();
  }

  void _startSearching() async {
    final listingId = widget.listingData['id'];
    final listerLatitude = widget.listingData['lister_latitude'];
    final listerLongitude = widget.listingData['lister_longitude'];
    final preferredDoerGender = widget.listingData['preferred_doer_gender'] ?? 'Any';
    List<dynamic> foundDoers = [];
    String? foundMessage;

    if (_manualRadius != null) {
      // Manual search with selected radius
      final response = await AsapService().searchDoers(
        listingId: listingId,
        listerLatitude: listerLatitude,
        listerLongitude: listerLongitude,
        preferredDoerGender: preferredDoerGender,
        maxDistance: _manualRadius!,
      );
      if (response['success'] == true && response['doers'] != null && response['doers'].isNotEmpty) {
        foundDoers = response['doers'];
        foundMessage = 'Doer(s) found within ${_manualRadius!.toInt()} km!';
      }
    } else {
      // Progressive radius search: 1km, 2km, 3km, 4km, 5km
      final List<double> radii = [1, 2, 3, 4, 5];
      for (final radius in radii) {
        final response = await AsapService().searchDoers(
          listingId: listingId,
          listerLatitude: listerLatitude,
          listerLongitude: listerLongitude,
          preferredDoerGender: preferredDoerGender,
          maxDistance: radius,
        );
        if (response['success'] == true && response['doers'] != null && response['doers'].isNotEmpty) {
          foundDoers = response['doers'];
          foundMessage = 'Doer(s) found within ${radius.toInt()} km!';
          break;
        }
      }
    }

    if (mounted) {
      if (foundDoers.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(foundMessage ?? 'Doer found!')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_manualRadius != null
              ? 'No doers found within ${_manualRadius!.toInt()} km.'
              : 'No doers found within 5 km.')),
      );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Searching for Doer'),
        automaticallyImplyLeading: false, // Prevent back button during search
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filter by Range',
            onPressed: () async {
              final selected = await showDialog<double>(
                context: context,
                builder: (context) {
                  double? tempRadius = _manualRadius ?? 1;
                  return AlertDialog(
                    title: const Text('Select Search Radius'),
                    content: StatefulBuilder(
                      builder: (context, setState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (double r in [1, 2, 3, 4, 5])
                              RadioListTile<double>(
                                title: Text('${r.toInt()} km'),
                                value: r,
                                groupValue: tempRadius,
                                onChanged: (val) {
                                  setState(() => tempRadius = val);
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, tempRadius),
                        child: const Text('Apply'),
                      ),
                    ],
                  );
                },
              );
              if (selected != null) {
                setState(() {
                  _manualRadius = selected;
                });
                _startSearching();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: Constants.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Improved loading animation
            Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Constants.primaryColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Constants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Searching...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Constants.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Searching for a doer for "${widget.listingData['title']}"...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Please wait while we find the best doer near your location.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 48),
            // You might add a cancel button here
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Allow user to cancel search
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel Search'),
            ),
          ],
        ),
      ),
    );
  }
}
