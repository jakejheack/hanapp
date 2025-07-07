import 'package:flutter/material.dart';
import 'package:hanapp/utils/auth_service.dart'; // Import your AuthService
import 'package:hanapp/models/user.dart'; // Import your User model
import 'package:hanapp/services/user_status_service.dart'; // Import user status service

// Import your screens
import 'package:hanapp/screens/auth/login_screen.dart';
import 'package:hanapp/screens/lister/lister_dashboard_screen.dart';
import 'package:hanapp/screens/doer/doer_dashboard_screen.dart';
import 'package:hanapp/screens/role_selection_screen.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  // This Future will hold the user data (or null if not logged in)
  late Future<User?> _checkLoginStatusFuture;

  @override
  void initState() {
    super.initState();
    _checkLoginStatusFuture = _checkLoginStatus();
  }

  Future<User?> _checkLoginStatus() async {
    // Retrieve user data from SharedPreferences
    User? user = await AuthService.getUser();
    return user;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _checkLoginStatusFuture,
      builder: (context, snapshot) {
        // While waiting for the future to complete, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF141CC9)),
              ),
            ),
          );
        } else {
          // If there's an error, log it and go to login
          if (snapshot.hasError) {
            debugPrint('Error checking login status: ${snapshot.error}');
            return const LoginScreen();
          }

          // Data is loaded, check user status
          final User? user = snapshot.data;

          if (user == null) {
            // No user data found, navigate to Login Screen
            return const LoginScreen();
          } else {
            // User data found, check role for navigation
            if (user.role == null || user.role!.isEmpty) {
              // User is logged in but has no role, go to Role Selection
              return const RoleSelectionScreen();
            } else if (user.role == 'lister') {
              // User is a Lister, go to Lister Dashboard
              return const ListerDashboardScreen();
            } else if (user.role == 'doer') {
              // User is a Doer, go to Doer Dashboard
              return const DoerDashboardScreen();
            } else {
              // Fallback for unexpected role, maybe go to Role Selection or Login
              debugPrint('Unknown user role: ${user.role}. Redirecting to Role Selection.');
              return const RoleSelectionScreen();
            }
          }
        }
      },
    );
  }
}
