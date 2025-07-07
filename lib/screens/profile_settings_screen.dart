// hanapp_flutter/lib/screens/profile_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hanapp/models/user.dart'; // Make sure this path is correct and User model has 'isAvailable'
import 'package:hanapp/screens/security_screen.dart';
import 'package:hanapp/screens/verification_screen.dart';
import 'package:hanapp/utils/auth_service.dart'; // Make sure this path is correct and AuthService has 'updateAvailabilityStatus'
import 'package:cached_network_image/cached_network_image.dart'; // For profile picture
import 'package:hanapp/utils/image_utils.dart'; // Import ImageUtils

// Import your dashboards (assuming these paths are correct)
import 'package:hanapp/screens/lister/lister_dashboard_screen.dart'; // Import ListerDashboardScreen
import 'package:hanapp/screens/doer/doer_dashboard_screen.dart';   // Import DoerDashboardScreen
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/user_status_service.dart';
import 'package:hanapp/services/app_lifecycle_service.dart'; // NEW: Import AppLifecycleService
import 'dart:async';

import 'because_screen.dart';
import 'doer/withdrawal_screen.dart'; // Assuming you have a constants file for colors
import 'package:hanapp/screens/wallet_screen.dart'; // NEW: Import WalletScreen
import 'package:hanapp/screens/terms_and_conditions_screen.dart';
import 'package:hanapp/screens/privacy_policy_screen.dart';
import 'package:hanapp/screens/lister/lister_reviews_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  User? _currentUser;
  bool _isLoadingRoleSwitch = false;
  bool _isAvailabilityLoading = false; // NEW: Loading state for active status switch
  bool _isLoading = false; // Loading state for general operations
  final AuthService _authService = AuthService();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser(); // Load user data when the screen initializes
    // Check for role mismatch when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkRoleMismatch();
      // Refresh user data after potential updates
      await _loadCurrentUser();
      // Force sync slider state
      _syncSliderWithLifecycleService();
      // Start periodic sync for doers
      _startPeriodicSync();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force refresh from backend and sync slider state when screen becomes visible
    _forceRefreshAndSync();
  }

  // Force refresh from backend and sync slider state
  Future<void> _forceRefreshAndSync() async {
    if (_currentUser?.role == 'doer') {
      print('ProfileSettings: Force refreshing status from backend...');
      await AppLifecycleService.instance.forceRefreshStatus();
      _syncSliderWithLifecycleService();
    }
  }
  
  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
  
  // Start periodic sync to keep slider in sync
  void _startPeriodicSync() {
    if (_currentUser?.role == 'doer') {
      _syncTimer?.cancel();
      int syncCount = 0;
      _syncTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (mounted) {
          _syncSliderWithLifecycleService();
          syncCount++;
          
          // Force refresh from backend every 30 syncs (30 seconds)
          if (syncCount % 30 == 0) {
            print('ProfileSettings: Periodic backend refresh...');
            await AppLifecycleService.instance.forceRefreshStatus();
          }
        }
      });
    }
  }
  

  
  // Update local state immediately when toggle is called
  void _updateLocalState(bool newValue) {
    if (_currentUser?.role == 'doer') {
      setState(() {
        _currentUser = _currentUser!.copyWith(isAvailable: newValue);
      });
      // Also update the lifecycle service local state
      AppLifecycleService.instance.setLocalOnlineStatus(newValue);
    }
  }

  // Sync slider state with AppLifecycleService
  void _syncSliderWithLifecycleService() {
    if (_currentUser?.role == 'doer') {
      final lifecycleStatus = AppLifecycleService.instance.isOnline;
      final currentStatus = _currentUser!.isAvailable ?? false;
      
      if (lifecycleStatus != currentStatus) {
        setState(() {
          _currentUser = _currentUser!.copyWith(isAvailable: lifecycleStatus);
        });
        print('ProfileSettings: Synced slider with lifecycle service - lifecycle: $lifecycleStatus, current: $currentStatus');
      }
    }
  }

  // Loads the current user from local storage
  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    setState(() {
      _currentUser = user;
    });
    
    // If user is a doer, refresh the lifecycle service user data and sync status
    if (user?.role == 'doer') {
      await AppLifecycleService.instance.refreshUser();
      // Sync the slider state with the lifecycle service
      _syncSliderWithLifecycleService();
    }
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

  // Helper to show snackbar messages with icon
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline, // Icon changes based on error
              color: Colors.white, // Icon color
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
        backgroundColor: isError ? Colors.red : Colors.green, // Background color changes
        behavior: SnackBarBehavior.floating, // Makes it float
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Rounded corners
        margin: const EdgeInsets.all(10), // Margin from edges
      ),
    );
  }

  // Logic for switching the user's role
  Future<void> _switchRole() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in or ID missing.', isError: true);
      return;
    }

    setState(() {
      _isLoadingRoleSwitch = true; // Show loading indicator
    });

    try {
      // NEW: First check for role mismatch and update if needed
      final roleUpdated = await UserStatusService.checkAndUpdateRoleMismatch(
        context: context,
        userId: _currentUser!.id!,
        showUpdateDialog: false, // Don't show dialog during role switch
      );

      // Reload user data if role was updated
      if (roleUpdated) {
        await _loadCurrentUser();
      }

      // Determine the new role based on the current role (after potential update)
      String newRole = (_currentUser!.role == 'lister') ? 'doer' : 'lister';

      // Call the AuthService to update the role in the backend AND locally
      final response = await _authService.updateRole(userId: _currentUser!.id.toString(), role: newRole);

      setState(() {
        _isLoadingRoleSwitch = false; // Hide loading indicator
      });

      if (response['success']) {
        // After successful role switch, reload the current user from local storage
        // This is crucial because AuthService.updateRole updates it locally.
        await _loadCurrentUser();

        _showSnackBar('Role switched to ${newRole.toUpperCase()}!');

        // Navigate to the appropriate dashboard based on the NEW role
        if (mounted) {
          if (_currentUser!.role == 'lister') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const ListerDashboardScreen()), // Go to Lister Dashboard
                  (Route<dynamic> route) => false, // Remove all previous routes
            );
          } else if (_currentUser!.role == 'doer') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DoerDashboardScreen()), // Go to Doer Dashboard
                  (Route<dynamic> route) => false, // Remove all previous routes
            );
          }
        }
      } else {
        _showSnackBar('Failed to switch role: ${response['message']}', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoadingRoleSwitch = false; // Hide loading indicator
      });
      _showSnackBar('Error switching role: $e', isError: true);
    }
  }

  // NEW: Logic for toggling active status (for Doers)
  Future<void> _toggleActiveStatus(bool newValue) async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in or ID missing.', isError: true);
      return;
    }
    if (_currentUser!.role != 'doer') {
      _showSnackBar('Only Doers can change their active status.', isError: true);
      return;
    }

    // Check if the status is actually changing
    final currentStatus = AppLifecycleService.instance.isOnline;
    if (currentStatus == newValue) {
      print('ProfileSettings: Status already ${newValue ? 'ON' : 'OFF'}, no change needed');
      return;
    }

    // Update local state immediately for instant response
    _updateLocalState(newValue);

    try {
      // Use the AppLifecycleService to toggle online status
      await AppLifecycleService.instance.toggleOnlineStatus(newValue);
      
      // Verify the status was actually updated
      await Future.delayed(const Duration(milliseconds: 500));
      final actualStatus = AppLifecycleService.instance.isOnline;
      
      if (actualStatus == newValue) {
        _showSnackBar('Active status updated to ${newValue ? 'ON' : 'OFF'}!');
      } else {
        // Revert local state if the actual status doesn't match
        _updateLocalState(actualStatus);
        _showSnackBar('Status update failed. Current status: ${actualStatus ? 'ON' : 'OFF'}', isError: true);
      }
    } catch (e) {
      // Revert local state on error
      _updateLocalState(currentStatus);
      _showSnackBar('Failed to update active status: $e', isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Show a loading indicator if current user data is not yet loaded
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Use ImageUtils to get the appropriate image provider
    ImageProvider<Object>? imageProvider = ImageUtils.createProfileImageProvider(_currentUser!.profilePictureUrl);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF141CC9), // Constants.primaryColor
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: imageProvider,
                    child: (imageProvider == null)
                        ? const Icon(Icons.person, size: 40, color: Colors.white)
                        : null,
                    onBackgroundImageError: imageProvider != null ? (exception, stackTrace) {
                      print('Profile Settings: Error loading profile image: $exception');
                      // Don't call setState during build - just log the error
                    } : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser!.fullName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        // Text(
                        //   _currentUser!.addressDetails ?? 'Location not set',
                        //   style: const TextStyle(fontSize: 16, color: Colors.white70),
                        // ),
                        const SizedBox(height: 8),
                        Text(
                          'Role: ${_currentUser!.role?.toUpperCase() ?? 'Not set'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _isLoadingRoleSwitch
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.sync_alt, color: Colors.white, size: 30),
                      onPressed: _switchRole, // This is the button that triggers the role switch
                      tooltip: 'Switch Role to ${_currentUser!.role == 'lister' ? 'Doer' : 'Lister'}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // NEW: Active Status Tile (only for Doer)
            if (_currentUser!.role == 'doer') // Conditionally display for Doers
              _buildSettingsTile(
                icon: Icons.power_settings_new, // Icon for active status
                title: 'Active Status',
                trailing: Switch(
                  value: _currentUser!.isAvailable ?? false, // Use local state for immediate response
                  onChanged: _toggleActiveStatus,
                  activeColor: Constants.primaryColor,
                ),
                onTap: () {
                  // Tapping the tile can also toggle the switch, or do nothing
                  // For now, it will just print a debug message.
                  debugPrint('Active Status tile tapped.');
                },
              ),

            _buildSettingsTile(
              icon: Icons.people,
              title: 'Community',
              onTap: () { Navigator.of(context).pushNamed('/community'); },
            ),
            _buildSettingsTile(
              icon: Icons.edit,
              title: 'Edit Profile',
              onTap: () { Navigator.of(context).pushNamed('/edit_profile'); },
            ),
            // Show "My Reviews" only for listers
            if (_currentUser!.role == 'lister')
              _buildSettingsTile(
                icon: Icons.rate_review,
                title: 'My Reviews',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ListerReviewsScreen(listerId: _currentUser!.id!),
                    ),
                  );
                },
              ),
            _buildSettingsTile(
              icon: Icons.account_balance_wallet,
              title: _currentUser!.role == 'lister' ? 'Hanapp Balance' : 'Withdrawal',
              onTap: () {
                if (_currentUser!.role == 'lister') {
                  Navigator.of(context).pushNamed('/WalletDetailsScreen');
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const WithdrawalScreen()), // Navigate to WithdrawalScreen
                  );
                }
              },
            ),
            // _buildSettingsTile(
            //   icon: Icons.verified_user,
            //   title: 'Make payment',
            //   onTap: () {
            //     Navigator.of(context).push(
            //       MaterialPageRoute(builder: (context) => const BecauseScreen()),
            //     );
            //   },
            // ),
            if (_currentUser!.role == 'lister')
              _buildSettingsTile(
                icon: Icons.rate_review,
                title: 'Make payment',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const BecauseScreen()),
                  );
                },
              ),
            _buildSettingsTile(
              icon: Icons.verified_user,
              title: 'Verification',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const VerificationScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.account_circle,
              title: 'Accounts',
              onTap: () { Navigator.of(context).pushNamed('/accounts'); },
            ),
            _buildSettingsTile(
              icon: Icons.security,
              title: 'Security',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SecurityScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.description,
              title: 'Terms & Conditions',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                await AuthService.logout();
                if (mounted) Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for consistent settings tile appearance
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing, // Allow custom trailing widget (e.g., Switch)
    String? subtitle, // Optional subtitle for additional information
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF34495E)),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
