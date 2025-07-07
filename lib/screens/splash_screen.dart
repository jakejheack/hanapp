// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:hanapp/models/user.dart'; // Ensure correct path
import 'package:hanapp/utils/auth_service.dart'; // Ensure correct path
import 'package:hanapp/screens/wrapper_with_verification.dart'; // Import new wrapper
import 'package:hanapp/screens/auth/login_screen.dart'; // Ensure correct path

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Animation Controller for the logo scaling
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Duration for one cycle of animation
    )..repeat(reverse: true); // Repeat the animation back and forth

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut, // Smooth easing
      ),
    );

    _checkUserAndNavigate();
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose the animation controller
    super.dispose();
  }

  // This function will check the user's authentication status and role
  // and then navigate to the appropriate screen.
  Future<void> _checkUserAndNavigate() async {
    // Optional: Add a delay to show your splash screen for a minimum duration
    await Future.delayed(const Duration(seconds: 3)); // Increased delay slightly to see animation

    final user = await AuthService.getUser(); // Fetch user data

    // Ensure the widget is still mounted before performing navigation
    if (!mounted) return;

    if (user != null) {
      // User is logged in, use the wrapper with verification
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WrapperWithVerification()),
      );
    } else {
      // No user found, navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141CC9), // Set Scaffold background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                'assets/hanapp_logo.jpg', // Replace with your actual image path
                width: 300, // Adjust size as needed
                height: 250,
              ),
            ),
            const SizedBox(height: 20), // Space between logo and loading text
            // const Text(
            //   'HanApp', // You can keep a text or remove it
            //   style: TextStyle(
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.white,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
