import 'package:flutter/material.dart';
import 'package:hanapp/models/doer_job.dart';
import 'package:hanapp/services/doer_job_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:intl/intl.dart'; // For date formatting

// Import the new form screens (still needed if they are used elsewhere or directly navigated to)
import 'package:hanapp/screens/doer/mark_job_complete_form_screen.dart'; // Keep for reference if needed
import 'package:hanapp/screens/doer/cancel_job_application_form_screen.dart'; // This is a separate form screen.
import 'package:hanapp/screens/chat_screen.dart'; // Import ChatScreen for 'View Chat' button

// Import the PublicListingDetailsScreen
import 'package:hanapp/screens/public_listing_details_screen.dart';
// Import ReviewScreen for checking reviews
import 'package:hanapp/screens/review_screen.dart';


class DoerJobListingsScreenMark extends StatefulWidget {
  const DoerJobListingsScreenMark({super.key});

  @override
  State<DoerJobListingsScreenMark> createState() => _DoerJobListingsScreenMarkState();
}

class _DoerJobListingsScreenMarkState extends State<DoerJobListingsScreenMark> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _wiggleAnimationController;
  late Animation<double> _wiggleAnimation;
  
  final List<String> _tabs = ['All', 'Ongoing', 'Pending', 'Complete', 'Cancelled'];
  User? _currentUser;
  bool _isLoadingUser = true;
  String? _userErrorMessage;

  final DoerJobService _doerJobService = DoerJobService();

  // Map to store jobs for each tab
  final Map<String, List<DoerJob>> _jobMap = {
    'All': [],
    'Ongoing': [],
    'Pending': [],
    'Complete': [],
    'Cancelled': [],
  };
  final Map<String, bool> _isLoadingJobs = {
    'All': false,
    'Ongoing': false,
    'Pending': false,
    'Complete': false,
    'Cancelled': false,
  };
  final Map<String, String?> _jobErrorMessages = {
    'All': null,
    'Ongoing': null,
    'Pending': null,
    'Complete': null,
    'Cancelled': null,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    // Initialize wiggle animation
    _wiggleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _wiggleAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _wiggleAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _wiggleAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _isLoadingUser = true;
      _userErrorMessage = null;
    });
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      _userErrorMessage = 'User not logged in.';
      if (mounted) Navigator.of(context).pushReplacementNamed('/login'); // Redirect to login if no user
    } else {
      _fetchJobsForTab('All'); // Fetch jobs for the initial tab (All)
    }
    setState(() {
      _isLoadingUser = false;
    });
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      final selectedTab = _tabs[_tabController.index];
      _fetchJobsForTab(selectedTab);
    }
  }

  Future<void> _fetchJobsForTab(String tabName) async {
    if (_currentUser == null) {
      _showSnackBar('User not logged in. Cannot fetch jobs.', isError: true);
      return;
    }

    setState(() {
      _isLoadingJobs[tabName] = true;
      _jobMap[tabName] = []; // Clear current list to show loading indicator clearly
      _jobErrorMessages[tabName] = null;
    });

    try {
      String filter = tabName.toLowerCase();
      if (filter == 'ongoing') filter = 'in_progress'; // Map 'Ongoing' tab to 'in_progress' status
      if (filter == 'complete') filter = 'completed'; // Map 'Complete' tab to 'completed' status

      print('DoerJobListingsScreen: Fetching jobs for tab: $tabName, filter: $filter');

      final response = await _doerJobService.getDoerJobListings(
        doerId: _currentUser!.id,
        statusFilter: filter,
      );

      print('DoerJobListingsScreen: Response received: $response');

      if (response['success']) {
        setState(() {
          _jobMap[tabName] = response['jobs'];
        });
        print('DoerJobListingsScreen: Set ${response['jobs'].length} jobs for tab: $tabName');
      } else {
        setState(() {
          _jobErrorMessages[tabName] = response['message'] ?? 'Failed to load jobs.';
        });
        print('DoerJobListingsScreen: Error for tab $tabName: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        _jobErrorMessages[tabName] = 'Network error: $e';
        debugPrint('Error fetching jobs for $tabName tab: $e');
      });
      print('DoerJobListingsScreen: Exception for tab $tabName: $e');
    } finally {
      setState(() {
        _isLoadingJobs[tabName] = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _markAsComplete(DoerJob job) async {
    // Instead of navigating to MarkJobCompleteFormScreen directly,
    // navigate to the ChatScreen for this job.
    // The "Mark as Done" button on the ChatScreen will then trigger the completion flow.
    _navigateToChat(job);
  }

  Future<void> _cancelApplication(DoerJob job) async {
    // Navigate to a dedicated cancellation form if needed, or directly handle it here.
    // For this flow, we will assume the cancellation is handled on the PublicListingDetailsScreen
    // if the doer clicks "Check Application" first, or from this screen directly.
    // If you have a separate CancelJobApplicationFormScreen, keep this navigation:
    final bool? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CancelJobApplicationFormScreen(
          applicationId: job.applicationId,
          listingTitle: job.title,
        ),
      ),
    );

    if (result == true) {
      _showSnackBar('Application cancelled successfully.');
      // Refresh all relevant tabs after cancellation
      _fetchJobsForTab('Pending');
      _fetchJobsForTab('Cancelled');
      _fetchJobsForTab('All');
    } else if (result == false) {
      _showSnackBar('Application cancellation aborted.');
    } else {
      // User dismissed the cancellation form without explicit action
      _showSnackBar('Cancellation process dismissed.');
    }
    _fetchJobsForTab(_tabs[_tabController.index]); // Always refresh the current tab
  }

  // UPDATED: This method now navigates to PublicListingDetailsScreen
  void _checkApplication(DoerJob job) {
    if (job.applicationId == null || job.listingId == null) {
      _showSnackBar('Application or Listing ID is missing for this job.', isError: true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublicListingDetailsScreen(
          listingId: job.listingId!, // Pass the listing ID
          applicationId: job.applicationId!, // Pass the application ID
        ),
      ),
    ).then((_) {
      // This block runs when returning from PublicListingDetailsScreen
      // Refresh the current tab to reflect any status changes (e.g., if application was cancelled)
      _fetchJobsForTab(_tabs[_tabController.index]);
    });
  }

  void _checkReviewGiven(DoerJob job) {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }
    
    // Navigate to the review screen in view mode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReviewScreen(
          reviewerId: job.listerId, // The lister who wrote the review
          reviewedUserId: _currentUser!.id!, // The current doer (who was reviewed)
          listingId: job.listingId,
          listingTitle: job.title,
          mode: 'view', // View mode to see the review
        ),
      ),
    );
  }

  void _navigateToChat(DoerJob job) {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }
    // Ensure that conversationId and listerId are available for chat navigation
    if (job.conversationId == null || job.listerId == 0) { // listerId being 0 might indicate an issue, better check for null if it's nullable in DoerJob
      _showSnackBar('Chat details not available for this job.', isError: true);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: job.conversationId!, // Use the conversation ID from the job
          otherUserId: job.listerId, // The Lister for this job
          listingTitle: job.title,
          applicationId: job.applicationId,
          isLister: false, // The current user is a Doer
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_userErrorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Job Listings'),
          backgroundColor: Constants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _userErrorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Listings'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tabName) {
          final jobsForTab = _jobMap[tabName]!;
          final bool isLoadingForTab = _isLoadingJobs[tabName]!;
          final String? errorMessageForTab = _jobErrorMessages[tabName];

          if (isLoadingForTab && jobsForTab.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (errorMessageForTab != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessageForTab,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (jobsForTab.isEmpty) {
            return Center(
              child: Text(
                'No jobs found in "${tabName}" category.',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _fetchJobsForTab(tabName),
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: jobsForTab.length,
              itemBuilder: (context, index) {
                final job = jobsForTab[index];
                return _buildJobCard(job);
              },
            ),
          );
        }).toList(),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed, // Ensures all items are visible
      //   selectedItemColor: Constants.primaryColor,
      //   unselectedItemColor: Colors.grey,
      //   currentIndex: 1, // Assuming "Job Listings" is the second icon (index 1)
      //   onTap: (index) {
      //     // Handle navigation to other main screens
      //     if (index == 0) {
      //       Navigator.of(context).pushReplacementNamed('/doer_dashboard');
      //     } else if (index == 1) {
      //       // Already on Job Listings (this screen)
      //     } else if (index == 2) {
      //       // Placeholder: Navigator.of(context).pushReplacementNamed('/notifications');
      //       _showSnackBar('Notifications (Coming Soon)');
      //     } else if (index == 3) {
      //       // Placeholder: Navigator.of(context).pushReplacementNamed('/profile_settings');
      //       _showSnackBar('Profile (Coming Soon)');
      //     }
      //   },
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.home),
      //       label: 'Home',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.check_circle), // Or Icons.work
      //       label: 'Jobs',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.notifications),
      //       label: 'Notifications',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.person),
      //       label: 'Profile',
      //     ),
      //   ],
      // ),
    );
  }

  Widget _buildJobCard(DoerJob job) {
    String statusText;
    Color statusColor;
    List<Widget> actionButtons = [];

    // Determine status text and color based on application status
    switch (job.applicationStatus) {
      case 'in_progress': // This is the "Ongoing" status for the Doer
        statusText = 'Ongoing';
        statusColor = Colors.green.shade600; // Deep green for ongoing
        actionButtons.add(
          ElevatedButton(
            onPressed: () => _markAsComplete(job), // This will now navigate to chat
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, // Distinct color for mark complete
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Mark as complete'),
          ),
        );
        actionButtons.add(const SizedBox(width: 8));
        actionButtons.add(
          ElevatedButton(
            onPressed: () => _navigateToChat(job), // Explicit button to view chat
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor, // Use primary color
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Chat'),
          ),
        );
        break;
      case 'pending':
        statusText = 'Pending';
        statusColor = Colors.orange;
        // Keep "Cancel Application" button here as an alternative to cancelling from details
        actionButtons.add(
          OutlinedButton(
            onPressed: () => _cancelApplication(job), // This calls the _cancelApplication method in this screen
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
        );
        actionButtons.add(const SizedBox(width: 8));
        actionButtons.add(
          ElevatedButton(
            onPressed: () => _checkApplication(job), // Calls the updated _checkApplication
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Check Application'),
          ),
        );
        break;
      case 'completed':
        statusText = 'Completed';
        statusColor = Colors.blue;
        actionButtons.add(
          ElevatedButton(
            onPressed: () => _checkReviewGiven(job),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Check Review Given'),
          ),
        );
        break;
      case 'cancelled':
        statusText = 'Cancelled';
        statusColor = Colors.red;
        break;
      case 'rejected':
        statusText = 'Rejected';
        statusColor = Colors.red;
        break;
      case 'accepted': // If 'accepted' is a distinct state before 'in_progress'
        statusText = 'Accepted';
        statusColor = Colors.green;
        actionButtons.add(
          ElevatedButton(
            onPressed: () => _navigateToChat(job), // Suggest navigating to chat to start
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Chat (Start Job)'),
          ),
        );
        break;
      default:
        statusText = 'Status: ${job.applicationStatus}';
        statusColor = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4, // Slightly higher elevation for better separation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multi-line titles
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.locationAddress,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            job.getTimeAgo(), // Using the helper from DoerJob model
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      if (job.isASAP) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100, // Red background for ASAP tag
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'ASAP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red, // Keep ASAP text red
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  // Use job.price if available in DoerJob model. Otherwise, fall back to listingId.
                  'Php ${job.price != null ? job.price!.toStringAsFixed(2) : job.listingId.toString()}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Constants.primaryColor),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1, color: Constants.lightGreyColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Views: ${job.views}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.people, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Applicants: ${job.applicantsCount}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status text and action buttons at the bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15), // Lighter background for status
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                Row(
                  children: actionButtons,
                ),
              ],
            ),
            // Conditional display for earned amount, transaction no, cancellation reason
            if (job.applicationStatus == 'completed' && job.earnedAmount != null) ...[
              const SizedBox(height: 8),
              Text(
                'Earned P${job.earnedAmount!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              if (job.transactionNo != null && job.transactionNo!.isNotEmpty)
                Text(
                  'Transaction No: ${job.transactionNo!}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
            if (job.applicationStatus == 'cancelled' && job.cancellationReason != null && job.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${job.cancellationReason!}',
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
              if (job.transactionNo != null && job.transactionNo!.isNotEmpty)
                Text(
                  'Transaction No: ${job.transactionNo!}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
