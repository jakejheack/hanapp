import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hanapp/services/notification_popup_service.dart';
import 'package:hanapp/models/notification_model.dart';
import 'package:hanapp/models/video.dart';
import 'package:hanapp/services/video_service.dart';
import 'package:hanapp/widgets/video_container.dart';
import 'package:hanapp/services/user_status_service.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? _currentUser;
  int _selectedIndex = 0; // To manage selected tab in BottomNavigationBar
  List<Video> _videos = [];
  bool _isLoadingVideos = false;
  final VideoService _videoService = VideoService();
  Timer? _roleCheckTimer; // Timer for polling

  @override
  void initState() {
    super.initState();
    print('DEBUG: Dashboard initState called');
    _loadCurrentUser();

    _loadVideos();
    // Start notification polling after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationPopupService().startPolling(context);
      _checkRoleMismatch(); // Check for role mismatch when screen loads
      _startRolePolling(); // Start periodic polling
    });
  }

  @override
  void dispose() {
    NotificationPopupService().stopPolling();
    _roleCheckTimer?.cancel(); // Cancel the timer
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    setState(() {});
  }

  // NEW: Check for role mismatch when screen loads
  Future<void> _checkRoleMismatch() async {
    if (_currentUser?.id != null) {
      await UserStatusService.checkAndUpdateRoleMismatch(
        context: context,
        userId: _currentUser!.id!,
        showUpdateDialog: true,
      );
      // Reload user data after potential update
      await _loadCurrentUser();
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation based on index
    switch (index) {
      case 0:
      // Home/Dashboard - already here
        break;
      case 1:
      // Applications/Jobs - navigate to appropriate screen
        Navigator.of(context).pushNamed('/job_listings');
        break;
      case 3:
      // Notifications
        Navigator.of(context).pushNamed('/notifications');
        break;
      case 4:
      // Profile
        if (_currentUser != null) {
          Navigator.of(context).pushNamed('/profile_settings'); // Navigates to the new ProfileSettingsScreen
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            if (_currentUser != null)
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: ImageUtils.createProfileImageProvider(_currentUser!.profilePictureUrl),
                    child: (_currentUser!.profilePictureUrl == null || _currentUser!.profilePictureUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_currentUser!.fullName}!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Role: ${_currentUser!.role ?? 'Not set'}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Dashboard Image/Banner
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage('assets/dashboard_image.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: const Center(
                child: Text(
                  'Need help with something?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Videos Section
            if (_videos.isNotEmpty) ...[
              
              VideoContainer(
                videos: _videos,
                title: 'Featured Videos',
                onViewAll: () {
                  // TODO: Navigate to full video list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video gallery coming soon!')),
                  );
                },
              ),
            ] else if (_isLoadingVideos) ...[
              const Center(child: CircularProgressIndicator()),
              const Text('Loading videos...'),
            ] else ...[

            ],
            
            if (_videos.isNotEmpty) const SizedBox(height: 24),

            // Quick Actions/Categories (placeholders)
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildQuickActionCard(Icons.work, 'Find Jobs', () {
                  Navigator.of(context).pushNamed('/job_listings');
                }),
                _buildQuickActionCard(Icons.list_alt, 'My Listings', () {
                  Navigator.of(context).pushNamed('/lister_dashboard');
                }),
                _buildQuickActionCard(Icons.chat, 'Messages', () {
                  Navigator.of(context).pushNamed('/chat_list');
                }),
                _buildQuickActionCard(Icons.history, 'History', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History not implemented yet.')),
                  );
                }),
                _buildQuickActionCard(Icons.notifications, 'Test Notification', () {
                  // Create a test notification
                  final testNotification = NotificationModel(
                    id: 999,
                    userId: _currentUser?.id ?? 0,
                    type: 'application_submitted',
                    title: 'Test Notification',
                    content: 'This is a test notification to demonstrate the popup functionality.',
                    createdAt: DateTime.now(),
                    isRead: false,
                  );
                  
                  // Show the popup notification
                  NotificationPopupService().showNotification(context, testNotification);
                }),
                _buildQuickActionCard(Icons.refresh, 'Check New Notifications', () {
                  // Manually trigger notification polling
                  NotificationPopupService().startPolling(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checking for new notifications...')),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the new screen when plus button is pressed
          Navigator.of(context).pushNamed('/choose_listing_type');
        },
        backgroundColor: const Color(0xFF141CC9),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF141CC9), // Set background color to the desired blue
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.home),
              color: _selectedIndex == 0 ? Colors.yellow.shade700 : Colors.white70, // Yellow indicator
              onPressed: () => _onItemTapped(0),
            ),
            IconButton(
              icon: Icon(Icons.assignment),
              color: _selectedIndex == 1 ? Colors.yellow.shade700 : Colors.white70, // Yellow indicator
              onPressed: () => _onItemTapped(1),
            ),
            const SizedBox(width: 48), // The space for the FAB
            IconButton(
              icon: Icon(Icons.notifications),
              color: _selectedIndex == 3 ? Colors.yellow.shade700 : Colors.white70, // Yellow indicator
              onPressed: () => _onItemTapped(3),
            ),
            IconButton(
              icon: Icon(Icons.person),
              color: _selectedIndex == 4 ? Colors.yellow.shade700 : Colors.white70, // Yellow indicator
              onPressed: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String title, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF141CC9)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}