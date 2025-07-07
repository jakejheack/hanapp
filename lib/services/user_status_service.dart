import 'package:flutter/material.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStatusService {
  static const String _lastCheckKey = 'last_user_status_check';
  static const Duration _checkInterval = Duration(minutes: 5); // Check every 5 minutes

  // NEW: Check for role mismatch and update local user data
  static Future<bool> checkAndUpdateRoleMismatch({
    required BuildContext context,
    required int userId,
    bool showUpdateDialog = true, // This param is now ignored
  }) async {
    try {
      // Get current local user
      final localUser = await AuthService.getUser();
      if (localUser == null) return false;

      // Check user status from server
      final response = await AuthService.checkUserStatus(
        userId: userId,
        action: 'check',
      );

      if (!response['success']) {
        print('UserStatusService: Failed to check user status: [31m${response['message']}[0m');
        return false;
      }

      final serverUser = response['user'];
      if (serverUser == null) return false;

      final serverRole = serverUser['role'];
      final localRole = localUser.role;

      // Check if there's a role mismatch
      if (serverRole != localRole) {
        print('UserStatusService: Role mismatch detected! Local: $localRole, Server: $serverRole');
        // Update local user data with server data
        final updatedUser = User.fromJson(serverUser);
        await AuthService.saveUser(updatedUser);
        // Automatically navigate to the correct dashboard (no popup)
        if (context.mounted) {
          if (serverRole == 'lister') {
            Navigator.of(context).pushReplacementNamed('/lister_dashboard');
          } else if (serverRole == 'doer') {
            Navigator.of(context).pushReplacementNamed('/doer_dashboard');
          }
        }
        return true; // Role was updated
      }

      return false; // No role mismatch
    } catch (e) {
      print('UserStatusService: Error checking role mismatch: $e');
      return false;
    }
  }

  // NEW: Show dialog when role has been updated from server
  static void _showRoleUpdatedDialog(BuildContext context, String oldRole, String newRole) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Role Updated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Your role has been updated from ${oldRole.toUpperCase()} to ${newRole.toUpperCase()} on the server.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'The app has been updated to reflect this change.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to appropriate dashboard based on new role
                if (newRole == 'lister') {
                  Navigator.of(context).pushReplacementNamed('/lister_dashboard');
                } else if (newRole == 'doer') {
                  Navigator.of(context).pushReplacementNamed('/doer_dashboard');
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // Check user status and handle errors
  static Future<bool> verifyUserStatus({
    required BuildContext context,
    required int userId,
    String action = 'check',
    bool showErrorDialog = true,
  }) async {
    try {
      final response = await AuthService.checkUserStatus(
        userId: userId,
        action: action,
      );

      if (!response['success']) {
        final errorType = response['error_type'];
        final message = response['message'];

        if (showErrorDialog) {
          _handleError(context, errorType, message, response);
        }
        return false;
      }

      return true;
    } catch (e) {
      print('UserStatusService: Error verifying user status: $e');
      if (showErrorDialog) {
        _showErrorDialog(
          context,
          'Verification Error',
          'Failed to verify user status. Please try again.',
        );
      }
      return false;
    }
  }

  // Handle different types of errors
  static void _handleError(BuildContext context, String? errorType, String message, Map<String, dynamic> response) {
    switch (errorType) {
      case 'account_deleted':
        _showAccountDeletedDialog(context, message);
        break;
      case 'account_banned':
        final bannedUntil = response['banned_until'];
        _showAccountBannedDialog(context, message, bannedUntil);
        break;
      case 'multiple_devices':
        _showMultipleDevicesDialog(context, message);
        break;
      case 'user_not_found':
        _showUserNotFoundDialog(context, message);
        break;
      default:
        _showErrorDialog(context, 'Verification Failed', message);
        break;
    }
  }

  // Show account deleted dialog
  static void _showAccountDeletedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Account Deleted'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await AuthService.clearUser();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show account banned dialog
  static void _showAccountBannedDialog(BuildContext context, String message, String? bannedUntil) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Account Banned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (bannedUntil != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Banned until: $bannedUntil',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AuthService.clearUser();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show multiple devices dialog
  static void _showMultipleDevicesDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Multiple Devices Detected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(message),
              const SizedBox(height: 8),
              const Text(
                'For security reasons, you can only use one device at a time.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AuthService.clearUser();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              child: const Text('Logout'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  // Show user not found dialog
  static void _showUserNotFoundDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('User Not Found'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await AuthService.clearUser();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show generic error dialog
  static void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Check if user status check is needed (based on time interval)
  static Future<bool> shouldCheckUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastCheck = Duration(milliseconds: now - lastCheck);
    
    return timeSinceLastCheck >= _checkInterval;
  }

  // Update last check timestamp
  static Future<void> updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Verify user status with interval checking
  static Future<bool> verifyUserStatusWithInterval({
    required BuildContext context,
    required int userId,
    String action = 'check',
    bool forceCheck = false,
  }) async {
    if (!forceCheck && !await shouldCheckUserStatus()) {
      return true; // Skip check if not enough time has passed
    }

    final result = await verifyUserStatus(
      context: context,
      userId: userId,
      action: action,
    );

    if (result) {
      await updateLastCheckTime();
    }

    return result;
  }
} 