import 'package:flutter/material.dart';
import 'package:hanapp/screens/lister/job_listing_screen.dart'; // Your existing job listings screen
import 'package:hanapp/screens/choose_listing_type_screen.dart'; // Corrected import: Screen to post new jobs
import 'package:hanapp/screens/profile_settings_screen.dart'; // Profile settings shared
import 'package:hanapp/screens/notifications_screen.dart'; // Notifications screen
import 'package:hanapp/screens/conversations_screen.dart'; // NEW: Import ConversationsScreen
import 'package:hanapp/screens/unified_chat_screen.dart'; // Unified chat screen
import 'package:hanapp/utils/constants.dart' as Constants; // For colors and padding
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/services/notification_service.dart'; // Add this import
import 'package:hanapp/models/user.dart';
import 'package:hanapp/services/notification_popup_service.dart';
import 'package:hanapp/models/video.dart';
import 'package:hanapp/services/video_service.dart';
import 'package:hanapp/widgets/video_container.dart';
import 'package:hanapp/widgets/inline_video_player.dart';
import 'package:hanapp/services/user_status_service.dart'; // Import user status service

import 'package:hanapp/screens/lister/combined_listings_screen.dart';

import 'doer_job_listings_mark_screen.dart';
import 'doer_job_listings_screen.dart'; // Import AuthService for logout

import 'dart:async';

class DoerDashboardScreen extends StatefulWidget {
  const DoerDashboardScreen({super.key});

  @override
  State<DoerDashboardScreen> createState() => _DoerDashboardScreenState();
}

class _DoerDashboardScreenState extends State<DoerDashboardScreen> {
  int _selectedIndex = 0; // To control BottomNavigationBar
  int _unreadCount = 0; // Add unread count state
  Timer? _roleCheckTimer; // Timer for polling

  // List of screens for the Owner/Lister role's Bottom Navigation Bar
  static final List<Widget> _ownerScreens = <Widget>[
    _ListerHomeScreenContent(), // Index 0: Home tab content
    const CombinedListingsScreen(), // Index 1: Jobs tab content
    const NotificationsScreen(), // Index 2: Notifications tab content
    const ProfileSettingsScreen(), // Index 3: Profile tab content
  ];

  // Titles corresponding to each screen/tab
  static const List<String> _screenTitles = <String>[
    'Doer',
    'Applications',
    'Notifications',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    // Start notification polling after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationPopupService().startPolling(context);
      _verifyUserStatus(); // Verify user status on screen load
      _startRolePolling(); // Start periodic polling
    });
  }

  @override
  void dispose() {
    NotificationPopupService().stopPolling();
    _roleCheckTimer?.cancel(); // Cancel the timer
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final user = await AuthService.getUser();
    if (user != null && user.id != null) {
      final response = await NotificationService().getUnreadCount(userId: user.id!);
      if (response['success']) {
        setState(() {
          _unreadCount = response['unread_count'] ?? 0;
        });
      }
    }
  }

  Future<void> _verifyUserStatus() async {
    final user = await AuthService.getUser();
    if (user != null && user.id != null) {
      // First check for role mismatch
      final roleUpdated = await UserStatusService.checkAndUpdateRoleMismatch(
        context: context,
        userId: user.id!,
        showUpdateDialog: true,
      );
      
      // If role was updated, we don't need to do further verification
      if (roleUpdated) {
        return;
      }
      
      // Otherwise, proceed with normal user status verification
      await UserStatusService.verifyUserStatusWithInterval(
        context: context,
        userId: user.id!,
        action: 'check',
        forceCheck: false,
      );
    }
  }

  void _startRolePolling() {
    _roleCheckTimer?.cancel();
    _roleCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      final user = await AuthService.getUser();
      if (user != null && user.id != null) {
        await UserStatusService.checkAndUpdateRoleMismatch(
          context: context,
          userId: user.id!,
          showUpdateDialog: false,
        );
      }
    });
  }

  void _onItemTapped(int index) {
    // Adjust index for _ownerScreens list as BottomAppBar has a FAB space
    int actualScreenIndex = index;
    if (index == 3) { // Notifications icon (index 3 in BottomAppBar row)
      actualScreenIndex = 2; // Corresponds to NotificationsScreen in _ownerScreens
      _loadUnreadCount(); // Refresh unread count when notifications tab is tapped
    } else if (index == 4) { // Profile icon (index 4 in BottomAppBar row)
      actualScreenIndex = 3; // Corresponds to ProfileSettingsScreen in _ownerScreens
    }

    setState(() {
      _selectedIndex = actualScreenIndex;
    });
  }

  Future<void> _logout() async {
    await AuthService.logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        Icon(
          Icons.notifications,
          color: _selectedIndex == 2 ? Colors.yellow.shade700 : Colors.white70,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[_selectedIndex]), // Dynamic title based on selected tab
        backgroundColor: Colors.white, // Consistent app bar color
        foregroundColor: Constants.primaryColor, // White icons/text for app bar
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline), // Chat icon
            onPressed: () {
              // Navigate to the new ConversationsScreen
              Navigator.of(context).pushNamed('/chat_list');
            },
            tooltip: 'Chats',
          ),
        ],
      ),
      body: _ownerScreens.elementAt(_selectedIndex), // Display the selected screen content
      bottomNavigationBar: BottomAppBar(
        color: Constants.primaryColor, // Consistent bottom app bar color
        shape: const CircularNotchedRectangle(), // Shape for FAB notch
        notchMargin: 8.0, // Margin for FAB notch
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.home),
              color: _selectedIndex == 0 ? Colors.yellow.shade700 : Colors.white70,
              onPressed: () => _onItemTapped(0),
            ),
            IconButton(
              icon: const Icon(Icons.list_alt), // Jobs tab icon
              color: _selectedIndex == 1 ? Colors.yellow.shade700 : Colors.white70,
              onPressed: () {
                // The plus button for posting a new job listing
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DoerJobListingsScreenMark()));
              },
            ),
            const SizedBox(width: 48), // Space for the Floating Action Button
            IconButton(
              icon: _buildNotificationIcon(), // Use the custom notification icon with badge
              onPressed: () => _onItemTapped(3), // Pass original index for logic
            ),
            IconButton(
              icon: const Icon(Icons.person),
              color: _selectedIndex == 3 ? Colors.yellow.shade700 : Colors.white70, // Corrected index for Profile
              onPressed: () {
                // The plus button for posting a new job listing
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()));
              }, // Pass original index for logic
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // The plus button for posting a new job listing
          Navigator.push(context, MaterialPageRoute(builder: (context) => const DoerJobListingsScreen()));
        },
        backgroundColor: Constants.primaryColor, // HANAPP Blue
        shape: const CircleBorder(),
        child: const Icon(Icons.search, color: Colors.white, size: 35),
      ),
    );
  }
}

// --- Existing Widget for the Lister Home Screen Content (no changes) ---
class _ListerHomeScreenContent extends StatefulWidget {
  @override
  State<_ListerHomeScreenContent> createState() => _ListerHomeScreenContentState();
}

class _ListerHomeScreenContentState extends State<_ListerHomeScreenContent> {
  List<Video> _videos = [];
  bool _isLoadingVideos = false;
  final VideoService _videoService = VideoService();

  @override
  void initState() {
    super.initState();
    print('DEBUG: Doer Home Screen initState called');
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoadingVideos = true;
      });

      final videos = await _videoService.getActiveVideos();
      
      setState(() {
        _videos = videos;
        _isLoadingVideos = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      setState(() {
        _isLoadingVideos = false;
      });
    }
  }

  Widget _buildVideoContent() {
    if (_isLoadingVideos) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading videos...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, size: 60, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Auto video play, promotions and tutorial',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show the first video with autoplay
    return InlineVideoPlayer(
      video: _videos.first,
      autoplay: true,
      height: 168, // 200 - 32 (padding)
      width: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: Constants.screenPadding, // Use consistent padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Announcement/Promo Code Area
          Card(
            margin: const EdgeInsets.only(bottom: 24.0),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                // Navigate to a screen showing announcement/promo code details
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnnouncementDetailsScreen()),
                );
              },
              child: Container(
                height: 120, // Height from image
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200], // Light grey background as per image
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Announcement Area', // Text from image
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'announcement/promo code of the day', // Subtext from image
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

          // "Need help with something?" List it here on HanApp!
          Card(
            margin: const EdgeInsets.only(bottom: 24.0),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                // Navigate to the screen for posting a new job
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DoerJobListingsScreen()),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.asset(
                      'assets/hanapp_logo.jpg', // Placeholder image from the image
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need Jobs?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your next job is just a tap away!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Auto video play, promotions and tutorial
          Card(
            margin: const EdgeInsets.only(bottom: 24.0),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildVideoContent(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Existing Placeholder Screen for Announcement Details (no changes) ---
class AnnouncementDetailsScreen extends StatelessWidget {
  const AnnouncementDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement/Promo Code'),
      ),
      body: const Padding(
        padding: Constants.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Announcement & Promo Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Here you can display the full details of the announcement or the daily promo code. This might include terms and conditions, validity dates, etc.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            Text(
              'Promo Code: HANAPP2024',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            Text(
              'Valid until: December 31, 2024',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            // Add more details as needed
          ],
        ),
      ),
    );
  }
}
