import 'package:flutter/material.dart';
import 'package:hanapp/utils/listing_service.dart';
import 'package:hanapp/models/listing.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';

class JobListingScreen extends StatefulWidget {
  const JobListingScreen({super.key});

  @override
  State<JobListingScreen> createState() => _JobListingScreenState();
}

class _JobListingScreenState extends State<JobListingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ListingService _listingService = ListingService();
  List<Listing> _allListings = [];
  List<Listing> _activeListings = [];
  List<Listing> _completedListings = [];
  bool _isLoading = true;
  String? _listerId; // To filter listings by the logged-in lister
  String? _doerId; // To filter listings for the doer (applications)
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args.containsKey('listerId')) {
        _listerId = args['listerId'].toString();
      }
      if (args.containsKey('doerId')) {
        _doerId = args['doerId'].toString();
      }
      _fetchListings();
    } else {
      // No listerId passed, so use the logged-in user
      _setListerIdAndFetch();
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // Rebuild the list based on selected tab, if needed
      });
    }
  }

  Future<void> _fetchListings() async {
    if (_listerId == null) {
      print('Error: listerId is null, cannot fetch listings.');
      // Optionally, try to reload user or show an error message
      await _setListerIdAndFetch();
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final response = await _listingService.getListings(
      status: 'all',
      listerId: _listerId,
      doerId: _doerId,
    );

    setState(() {
      _isLoading = false;
      if (response['success']) {
        List<Listing> all = response['listings'];
        // Filter by current user as lister
        if (_currentUser != null) {
          all = all.where((l) => l.listerId == _currentUser!.id).toList();
        }
        _allListings = all;
        _activeListings = _allListings.where((l) => l.status == 'active').toList();
        _completedListings = _allListings.where((l) => l.status == 'completed').toList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load listings: ${response['message']}')),
        );
      }
    });
  }

  Future<void> _setListerIdAndFetch() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        _listerId = user.id.toString();
      });
      await _fetchListings();
    }
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    setState(() {});
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildListingCard(Listing listing) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/listing_details', arguments: listing.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (listing.imageUrl != null && listing.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: listing.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Icon(Icons.image, size: 40, color: Colors.grey),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            listing.address.split(',').first.trim(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _getTimeAgo(listing.createdAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₱${listing.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Views: ${listing.views}', // Display views
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.group, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Applicants: ${listing.applicantsCount}', // Display applicants count
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Icon for status (e.g., checkmark for completed)
              if (listing.status == 'completed')
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 24),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Listings'),
        backgroundColor: const Color(0xFF141CC9), // HANAPP Blue
        foregroundColor: Colors.white, // White text/icons
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Selected tab text color
          unselectedLabelColor: Colors.white70, // Unselected tab text color
          indicatorColor: Colors.blue, // Indicator line color
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'), // New tab
            Tab(text: 'Complete'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // All Listings Tab
          _allListings.isEmpty
              ? const Center(child: Text('No listings found.'))
              : ListView.builder(
            itemCount: _allListings.length,
            itemBuilder: (context, index) {
              return _buildListingCard(_allListings[index]);
            },
          ),
          // Active Listings Tab
          _activeListings.isEmpty
              ? const Center(child: Text('No active listings.'))
              : ListView.builder(
            itemCount: _activeListings.length,
            itemBuilder: (context, index) {
              return _buildListingCard(_activeListings[index]);
            },
          ),
          // Completed Listings Tab
          _completedListings.isEmpty
              ? const Center(child: Text('No completed listings.'))
              : ListView.builder(
            itemCount: _completedListings.length,
            itemBuilder: (context, index) {
              return _buildListingCard(_completedListings[index]);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/enter_listing_details');
        },
        backgroundColor: const Color(0xFF141CC9),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}