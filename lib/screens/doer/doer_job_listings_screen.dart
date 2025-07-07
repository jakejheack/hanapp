import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanapp/viewmodels/doer_job_listings_view_model.dart'; // Ensure correct path
import 'package:hanapp/models/doer_listing_item.dart'; // Ensure correct path
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/screens/doer/doer_job_filter_modal.dart'; // Import the filter modal
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils for profile pictures

class DoerJobListingsScreen extends StatefulWidget {
  const DoerJobListingsScreen({super.key});

  @override
  State<DoerJobListingsScreen> createState() => _DoerJobListingsScreenState();
}

class _DoerJobListingsScreenState extends State<DoerJobListingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshingButton = false; // State variable for refresh icon loading
  bool _showCenterLoading = false; // NEW: State variable for center loading

  @override
  void initState() {
    super.initState();
    // No need to call fetchJobListings here, ViewModel's constructor does it.
    // Ensure the ViewModel is provided higher up in the widget tree.
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Method to show the filter modal
  void _showFilterModal() async {
    final viewModel = Provider.of<DoerJobListingsViewModel>(context, listen: false);

    final Map<String, dynamic>? filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return DoerJobFilterModal(
          initialDistance: viewModel.distanceFilter,
          initialMinBudget: viewModel.minBudgetFilter,
          initialDatePosted: viewModel.datePostedFilter,
        );
      },
    );

    if (filters != null) {
      viewModel.applyFilters(
        distance: filters['distance'],
        minBudget: filters['minBudget'],
        datePosted: filters['datePosted'],
        // category and searchQuery are managed by their respective UI elements
      );
    }
  }

  // Method to handle refresh button press
  Future<void> _handleRefreshButton() async {
    setState(() {
      _isRefreshingButton = true; // Show loading on button
      _showCenterLoading = true; // Show loading in center
    });

    final viewModel = Provider.of<DoerJobListingsViewModel>(context, listen: false);
    await viewModel.fetchJobListings(); // Fetch new data

    setState(() {
      _isRefreshingButton = false; // Hide loading on button
      _showCenterLoading = false; // Hide loading in center
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom AppBar-like section
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16, // Adjust for status bar and padding
              left: 16,
              right: 16,
              bottom: 16,
            ),
            color: Constants.primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Listing Job',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Rescan button - refresh search results
                    IconButton(
                      icon: _isRefreshingButton
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _isRefreshingButton ? null : _handleRefreshButton, // Disable while loading
                      tooltip: 'Refresh Results',
                    ),
                    // Filter icon - now calls _showFilterModal
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: _showFilterModal, // Call the new method
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (value) {
                      Provider.of<DoerJobListingsViewModel>(context, listen: false)
                          .setSearchQuery(value);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Tabs
          Consumer<DoerJobListingsViewModel>(
            builder: (context, viewModel, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCategoryTab('All', viewModel),
                    _buildCategoryTab('Onsite', viewModel),
                    _buildCategoryTab('Hybrid', viewModel),
                    _buildCategoryTab('Remote', viewModel),
                  ],
                ),
              );
            },
          ),

          // Job Listings List with RefreshIndicator
          Expanded(
            child: Stack( // Use Stack to overlay the loading indicator
              children: [
                Consumer<DoerJobListingsViewModel>(
                  builder: (context, viewModel, child) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        // This handles pull-to-refresh, which can also trigger a full reload
                        await viewModel.fetchJobListings();
                      },
                      color: Constants.primaryColor,
                      child: viewModel.isLoading && viewModel.listings.isEmpty && !_showCenterLoading // Only show initial loading if no data and not explicit refresh
                          ? const Center(child: CircularProgressIndicator())
                          : viewModel.errorMessage != null
                          ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error: ${viewModel.errorMessage}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        ),
                      )
                          : viewModel.listings.isEmpty
                          ? const Center(
                        child: Text(
                          'No jobs found matching your criteria.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        itemCount: viewModel.listings.length,
                        itemBuilder: (context, index) {
                          final listing = viewModel.listings[index];
                          return _buildJobListingCard(listing);
                        },
                      ),
                    );
                  },
                ),
                // NEW: Center loading indicator for button refresh
                if (_showCenterLoading)
                  Container(
                    color: Colors.white.withOpacity(0.8), // Semi-transparent overlay
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Constants.primaryColor),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Refreshing job listings...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

  Widget _buildCategoryTab(String category, DoerJobListingsViewModel viewModel) {
    bool isSelected = viewModel.selectedCategory == category;
    return GestureDetector(
      onTap: () {
        viewModel.setSelectedCategory(category);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Constants.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Constants.primaryColor : Colors.transparent),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildJobListingCard(DoerListingItem listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
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
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lister's Profile Picture
                CircleAvatar(
                  radius: 30,
                  backgroundImage: ImageUtils.createProfileImageProvider(listing.listerProfilePictureUrl) ??
                      const AssetImage('assets/default_profile.png') as ImageProvider,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('DoerListing: Error loading profile image: $exception');
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Constants.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.description ?? 'No description provided.',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.locationAddress?.split(',').first.trim() ?? 'Unknown',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: listing.listingType == 'ASAP'
                                    ? Colors.red.shade100 // Red background for ASAP tag
                                    : Constants.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                listing.listingType == 'ASAP' ? 'ASAP' : listing.category,
                                style: TextStyle(
                                  color: listing.listingType == 'ASAP' ? Colors.red : Constants.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (listing.price != null && listing.price! > 0)
                      Text(
                        '₱${listing.price!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Constants.primaryColor,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      listing.getTimeAgo(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
