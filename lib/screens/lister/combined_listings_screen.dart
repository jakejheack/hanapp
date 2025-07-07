import 'package:flutter/material.dart';
import 'package:hanapp/viewmodels/combined_listings_view_model.dart'; // Ensure correct path
import 'package:hanapp/models/combined_listing_item.dart'; // Ensure correct path
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:provider/provider.dart'; // Your constants
import 'package:hanapp/utils/auth_service.dart'; // Import AuthService

class CombinedListingsScreen extends StatefulWidget {
  const CombinedListingsScreen({super.key});

  @override
  State<CombinedListingsScreen> createState() => _CombinedListingsScreenState();
}

class _CombinedListingsScreenState extends State<CombinedListingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Fetch data when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchListingsWithUser();
    });
  }

  Future<void> _fetchListingsWithUser() async {
    final user = await AuthService.getUser();
    if (user != null && user.id != null) {
      Provider.of<CombinedListingsViewModel>(context, listen: false)
          .fetchCombinedListings(listerId: user.id);
    } else {
      // Handle case where user is not found
      print('Error: User not found or user ID is null');
      // Optionally show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view your listings.')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper function to format time ago
  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  void _showJobCompletedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This job has been completed and is no longer accepting applications.'),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // TabBar
          Container(
            color: Constants.primaryColor, // Background color for the TabBar
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Active'),
                Tab(text: 'Completed'), // Changed 'Complete' to 'Completed' for consistency
              ],
            ),
          ),

          // TabBarView takes the remaining space
          Expanded(
            child: Consumer<CombinedListingsViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (viewModel.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: ${viewModel.errorMessage}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  );
                } else {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListingList(viewModel.allListings),
                      _buildListingList(viewModel.activeListings),
                      _buildListingList(viewModel.completedListings),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build the list of listings for each tab
  Widget _buildListingList(List<CombinedListingItem> listings) {
    if (listings.isEmpty) {
      return const Center(
        child: Text(
          'No listings found for this category.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        final bool isCompleted = listing.status == 'completed'; // Assuming 'COMPLETED' status

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              if (isCompleted) {
                _showJobCompletedMessage(); // Show message if completed
              } else {
                // Navigate to appropriate details screen based on listing type
                if (listing.listingType == 'ASAP') {
                  Navigator.of(context).pushNamed(
                    '/asap_listing_details',
                    arguments: {'listing_id': listing.id},
                  );
                } else { // PUBLIC
                  Navigator.of(context).pushNamed(
                    '/public_listing_details',
                    arguments: {'listing_id': listing.id},
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.grey : Constants.textColor, // Dim title if completed
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (listing.price != null && listing.price! > 0)
                        Text(
                          '₱${listing.price!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.grey : Constants.primaryColor, // Dim price if completed
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (listing.locationAddress ?? 'Location not specified').split(',').first.trim(),
                          style: TextStyle(fontSize: 10, color: isCompleted ? Colors.grey : Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _getTimeAgo(listing.createdAt),
                        style: TextStyle(fontSize: 14, color: isCompleted ? Colors.grey : Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Displaying Views and Applicants
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Views: ${listing.views}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted ? Colors.grey : Constants.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Applicants: ${listing.applicants}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted ? Colors.grey : Constants.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Displaying 'ASAP' tag or 'Completed' tag
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.blueGrey.shade100 // New color for completed tag
                            : listing.listingType == 'ASAP'
                            ? Colors.red.shade100
                            : Constants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed' // Display 'COMPLETED' if job is done
                            : listing.listingType == 'ASAP'
                            ? 'ASAP'
                            : listing.category,
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.blueGrey.shade700 // Text color for completed tag
                              : listing.listingType == 'ASAP'
                              ? Colors.red
                              : Constants.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
