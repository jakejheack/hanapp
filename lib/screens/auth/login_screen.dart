import 'package:flutter/material.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hanapp/utils/auth_service.dart'; // Assuming this exists
import 'package:hanapp/screens/components/custom_button.dart'; // Our custom button
import 'package:hanapp/screens/components/custom_text_field.dart'; // Our custom text field
import 'package:hanapp/utils/constants.dart'; // Our constants for colors and padding
import 'package:hanapp/models/user.dart'; // Import the User model
import 'package:hanapp/services/user_status_service.dart'; // Import user status service

// Import your dashboard screens and role selection screen
import 'package:hanapp/screens/lister/lister_dashboard_screen.dart';
import 'package:hanapp/screens/doer/doer_dashboard_screen.dart';
import 'package:hanapp/screens/role_selection_screen.dart';
import 'package:hanapp/screens/auth/forgot_password_screen.dart';
import 'package:hanapp/screens/auth/social_completion_screen.dart';

import '../../utils/constants.dart' as Constants;
// import 'package:hanapp/services/google_auth_service.dart'; // Commented out - Firebase-based


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); // Assuming AuthService is correctly implemented
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Added for form validation
  bool _passwordVisible = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showBannedAccountDialog(String message, String bannedUntil) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red.shade700, size: 30),
              const SizedBox(width: 10),
              const Text('Account Banned', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Banned until: $bannedUntil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _showDeletedAccountDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red.shade700, size: 30),
              const SizedBox(width: 10),
              const Text('Account Deleted', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This account has been permanently deleted and cannot be recovered.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) { // Validate form before login
      setState(() {
        _isLoading = true;
      });

      // Assuming loginUser returns a Map with 'success' and 'message'
      final response = await _authService.loginUser(
        _emailController.text,
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      // Debug logging
      print('Login Screen: Response received: $response');
      print('Login Screen: Response success: ${response['success']}');
      print('Login Screen: Response error_type: ${response['error_type']}');
      print('Login Screen: Response message: ${response['message']}');
      print('Login Screen: Response keys: ${response.keys.toList()}');

      if (response['success']) {
        _showSnackBar(response['message']);

        // --- NEW LOGIC FOR ROLE-BASED NAVIGATION ---
        User? loggedInUser = await AuthService.getUser(); // Retrieve the logged-in user's data
        
        // Debug: Print user data after login
        if (loggedInUser != null) {
          print('Login Screen: User logged in successfully');
          print('Login Screen: User ID: ${loggedInUser.id}');
          print('Login Screen: User Name: ${loggedInUser.fullName}');
          print('Login Screen: User Role: ${loggedInUser.role}');
          print('Login Screen: Profile Picture URL: ${loggedInUser.profilePictureUrl}');
        } else {
          print('Login Screen: Failed to get user data after login');
        }

        if (mounted && loggedInUser != null) {
          // Verify user status before navigation
          final isStatusValid = await UserStatusService.verifyUserStatus(
            context: context,
            userId: loggedInUser.id!,
            action: 'login', // Use 'login' action to check for multiple devices
          );

          if (isStatusValid) {
            // Navigate based on role
            if (loggedInUser.role == null || loggedInUser.role!.isEmpty) {
              Navigator.of(context).pushReplacementNamed('/role_selection');
            } else if (loggedInUser.role == 'lister') {
              Navigator.of(context).pushReplacementNamed('/lister_dashboard');
            } else if (loggedInUser.role == 'doer') {
              Navigator.of(context).pushReplacementNamed('/doer_dashboard');
            } else {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          }
          // If status is not valid, UserStatusService will show appropriate dialog
        }
        // --- END NEW LOGIC ---

      } else {
        // Check for specific error types from backend
        if (response['error_type'] == 'account_banned') {
          _showBannedAccountDialog(response['message'], response['banned_until'] ?? 'Unknown date');
        } else if (response['error_type'] == 'account_deleted') {
          _showDeletedAccountDialog(response['message']);
        } else {
          _showSnackBar(response['message'], isError: true);
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final deviceInfo = await _getDeviceInfo();
      final locationDetails = await _getLocationDetails();

      final response = await AuthService.signInWithGoogle(
        deviceInfo: deviceInfo,
        locationDetails: locationDetails,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        // Check if profile needs completion
        if (response['needs_completion'] == true) {
          _showSnackBar('Please complete your profile to continue');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SocialCompletionScreen(
                socialUserData: response['social_user_data'],
              ),
            ),
          );
          return;
        }

        // Check if user needs role selection
        if (response['needs_role_selection'] == true) {
          _showSnackBar('Please choose your role to continue');
          Navigator.of(context).pushReplacementNamed('/role_selection');
          return;
        }

        _showSnackBar('Google sign-in successful!');

        // Navigate based on user data
        User? loggedInUser = await AuthService.getUser();
        if (mounted && loggedInUser != null) {
          if (loggedInUser.role == null || loggedInUser.role!.isEmpty || loggedInUser.role == 'user') {
            Navigator.of(context).pushReplacementNamed('/role_selection');
          } else if (loggedInUser.role == 'lister') {
            Navigator.of(context).pushReplacementNamed('/lister_dashboard');
          } else if (loggedInUser.role == 'doer') {
            Navigator.of(context).pushReplacementNamed('/doer_dashboard');
          }
        }
      } else {
        _showSnackBar(response['message'], isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Google sign-in failed: $e', isError: true);
    }
  }

  Future<void> _signInWithFacebook() async {
    print('=== Facebook Sign-In Button Pressed ===');
    setState(() {
      _isLoading = true;
    });

    try {
      final deviceInfo = await _getDeviceInfo();
      final locationDetails = await _getLocationDetails();

      final response = await AuthService.signInWithFacebook(
        deviceInfo: deviceInfo,
        locationDetails: locationDetails,
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        // Check if profile needs completion
        if (response['needs_completion'] == true) {
          _showSnackBar('Please complete your profile to continue');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SocialCompletionScreen(
                socialUserData: response['social_user_data'],
              ),
            ),
          );
          return;
        }

        // Check if user needs role selection
        if (response['needs_role_selection'] == true) {
          _showSnackBar('Please choose your role to continue');
          Navigator.of(context).pushReplacementNamed('/role_selection');
          return;
        }

        _showSnackBar('Facebook sign-in successful!');

        // Navigate based on user data
        User? loggedInUser = await AuthService.getUser();
        if (mounted && loggedInUser != null) {
          if (loggedInUser.role == null || loggedInUser.role!.isEmpty || loggedInUser.role == 'user') {
            Navigator.of(context).pushReplacementNamed('/role_selection');
          } else if (loggedInUser.role == 'lister') {
            Navigator.of(context).pushReplacementNamed('/lister_dashboard');
          } else if (loggedInUser.role == 'doer') {
            Navigator.of(context).pushReplacementNamed('/doer_dashboard');
          }
        }
      } else {
        _showSnackBar(response['message'], isError: true);
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Facebook sign-in failed: $e', isError: true);
    }
  }

  // Handler methods for social login buttons (return void)
  void _handleGoogleSignIn() {
    _signInWithGoogle();
  }

  void _handleFacebookSignIn() {
    _signInWithFacebook();
  }

  // Temporary function to show Facebook coming soon message
  void _showFacebookComingSoonMessage() {
    _showSnackBar('Facebook Login coming soon! Please use email or Google sign-in for now.', isError: false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper to get device information
  Future<String> _getDeviceInfo() async {
    String deviceInfoString = 'Unknown Device';
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceInfoString = '${androidInfo.manufacturer ?? 'Unknown'} ${androidInfo.model ?? 'Unknown'} (Android ${androidInfo.version.release ?? 'Unknown'})';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceInfoString = '${iosInfo.model ?? 'Unknown'} (iOS ${iosInfo.systemVersion ?? 'Unknown'})';
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        deviceInfoString = '${windowsInfo.computerName ?? 'Unknown'} (Windows ${windowsInfo.majorVersion ?? 'Unknown'}.${windowsInfo.minorVersion ?? 'Unknown'})';
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo macOsInfo = await deviceInfo.macOsInfo;
        deviceInfoString = '${macOsInfo.model ?? 'Unknown'} (macOS ${macOsInfo.kernelVersion ?? 'Unknown'})';
      } else if (Platform.isLinux) {
        LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
        deviceInfoString = '${linuxInfo.name ?? 'Unknown'} (Linux ${linuxInfo.version ?? 'Unknown'})';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    return deviceInfoString;
  }

  Future<String?> _getLocationDetails() async {
    // Implement actual geolocation here using geolocator/geocoding packages if needed.
    // Ensure you handle permissions.
    return 'General Trias, Philippines'; // Placeholder for demonstration
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView( // Use SingleChildScrollView to prevent overflow
        padding: Constants.screenPadding, // Use consistent padding from constants.dart
        child: Form( // Wrap with Form for validation
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
            children: [
              const SizedBox(height: 50), // Space from top/app bar

              const Text(
                'LOG IN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Constants.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30), // Space after LOG IN title

              CustomTextField(
                labelText: 'Email',
                hintText: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16), // Space between email and password fields

              CustomTextField(
                labelText: 'Password',
                hintText: 'Enter your password',
                controller: _passwordController,
                obscureText: !_passwordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Constants.textColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Constants.primaryColor, // Blue text
                  ),
                  child: const Text(
                    'Forgot your password?',
                    style: TextStyle(fontSize: 14), // Smaller font as in image
                  ),
                ),
              ),
              const SizedBox(height: 24), // Space before continue button

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                text: 'Continue',
                onPressed: _login,
                color: Constants.primaryColor, // Solid blue background
                textColor: Constants.buttonTextColor, // White text
                borderRadius: 25.0, // More rounded corners for this button
                height: 50.0, // Consistent height
              ),
              const SizedBox(height: 16), // Space after continue button

              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/register'); // Assuming '/signup1' is your first signup screen route
                },
                style: TextButton.styleFrom(
                  foregroundColor: Constants.textColor, // Default text color
                ),
                child: RichText(
                  text: TextSpan(
                    text: "Don't have a HANAPP account? ",
                    style: const TextStyle(color: Constants.textColor, fontSize: 16),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Sign up here',
                        style: const TextStyle(
                          color: Constants.primaryColor, // Blue for "Sign up here"
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24), // Space before social logins

              // Social login buttons (styled as outlined buttons)
              // Google sign-in temporarily disabled - Firebase-based
              CustomButton(
                text: 'Continue with Google',
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                color: Colors.white, // White background
                textColor: Constants.socialButtonTextColor, // Black text
                borderSide: const BorderSide(color: Constants.socialButtonBorderColor, width: 1.0), // Blue border
                borderRadius: 8.0, // Standard rounded corners
                height: 50.0,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Continue with Facebook',
                onPressed: _isLoading ? null : _handleFacebookSignIn,
                color: Colors.white, // White background
                textColor: Constants.socialButtonTextColor, // Black text
                borderSide: const BorderSide(color: Constants.socialButtonBorderColor, width: 1.0), // Blue border
                borderRadius: 8.0, // Standard rounded corners
                height: 50.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}