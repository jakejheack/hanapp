import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File
import 'dart:async'; // NEW: Import for Timer
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/services/verification_service.dart';
import 'package:hanapp/utils/auth_service.dart'; // For User model and AuthService
import 'package:hanapp/models/user.dart'; // User model
import 'package:hanapp/screens/face_verification_screen.dart';
import 'package:hanapp/screens/verified_badge_payment_screen.dart'; // NEW: Import payment screen
import 'live_photo_capture_screen.dart'; // NEW: Import for face recognition step
import 'package:hanapp/widgets/animated_wiggle_button.dart'; // NEW: Import animated wiggle button

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String? _selectedIdType;
  XFile? _idPhotoFront; // Stores the selected front ID image file
  XFile? _idPhotoBack; // Stores the selected back ID image file
  XFile? _brgyClearancePhoto; // NEW: Barangay Clearance photo
  bool? _confirmIdBelongsToUser; // Yes/No radio button state
  bool _isLoading = false; // For submission loading indicator

  User? _currentUser; // Current logged-in user
  String _currentVerificationStatus = 'unverified';
  bool _isBadgeAcquired = false;
  bool _isIdVerified = false; // If ID documents are fully accepted by admin
  bool _isWiggleAnimating = false; // NEW: Control wiggle animation for Get Badge button
  bool _isDialogButtonWiggling = false; // NEW: Control wiggle animation for dialog button
  Timer? _wiggleTimer; // NEW: Timer for periodic wiggle animation
  Timer? _dialogButtonTimer; // NEW: Timer for periodic dialog button wiggle animation

  final VerificationService _verificationService = VerificationService();
  final ImagePicker _picker = ImagePicker();

  final List<String> _idTypes = [
    'Passport',
    'Driver\'s License',
    'National ID',
    'Voter\'s ID',
    'PhilHealth ID',
    'UMID',
    'Postal ID',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAndVerificationStatus();
  }

  @override
  void dispose() {
    _wiggleTimer?.cancel(); // NEW: Cancel timer when disposing
    _dialogButtonTimer?.cancel(); // NEW: Cancel dialog button timer when disposing
    super.dispose();
  }

  Future<void> _loadUserAndVerificationStatus() async {
    setState(() {
      _isLoading = true;
    });
    try {
      print('VerificationScreen: Loading user and verification status...');

      print('VerificationScreen: Calling AuthService.fetchAndSetUser()...');
      try {
        await AuthService.fetchAndSetUser(); // Ensure latest user data is loaded
        print('VerificationScreen: fetchAndSetUser() completed successfully');
      } catch (e) {
        print('VerificationScreen: ERROR in fetchAndSetUser(): $e');
        throw e;
      }

      print('VerificationScreen: Calling AuthService.getUser()...');
      try {
        _currentUser = await AuthService.getUser();
        print('VerificationScreen: getUser() completed successfully');
      } catch (e) {
        print('VerificationScreen: ERROR in getUser(): $e');
        throw e;
      }

      if (_currentUser == null || _currentUser!.id == null) {
        print('VerificationScreen: User not logged in');
        _showSnackBar('User not logged in. Please log in to verify.', isError: true);
        if (mounted) Navigator.of(context).pushReplacementNamed('/login'); // Redirect to login
        return;
      }

      print('VerificationScreen: User loaded successfully. ID: ${_currentUser!.id}');

      print('VerificationScreen: Calling _verificationService.getVerificationStatus()...');
      try {
        final response = await _verificationService.getVerificationStatus(userId: _currentUser!.id!);
        print('VerificationScreen: getVerificationStatus() completed successfully');

          if (response['success']) {
            final statusData = response['status_data'];
        print('VerificationScreen: Status data received: $statusData');
        print('VerificationScreen: verification_status type: ${statusData['verification_status'].runtimeType}');
        print('VerificationScreen: verification_status value: ${statusData['verification_status']}');

        setState(() {
          // Safely handle potential type casting issues
          _currentVerificationStatus = _safeStringValue(statusData['verification_status'], 'unverified');
          _isIdVerified = statusData['id_verified'] ?? false;
          _isBadgeAcquired = statusData['badge_acquired'] ?? false;
          // You might also want to load previously uploaded ID paths if the status allows re-upload
          // _idPhotoFront = statusData['id_photo_front_url'] != null ? XFile(Constants.apiUrl + '/' + statusData['id_photo_front_url']) : null;
          // _idPhotoBack = statusData['id_photo_back_url'] != null ? XFile(Constants.apiUrl + '/' + statusData['id_photo_back_url']) : null;
        });

        // Show badge prompt if ID is verified but badge not acquired
        if (_isIdVerified && !_isBadgeAcquired) {
          // Start wiggle animation for the Get Badge button
          setState(() {
            _isWiggleAnimating = true;
          });
          
          // Stop animation after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isWiggleAnimating = false;
              });
            }
          });
          
          // Start periodic wiggle animation to draw attention
          _startPeriodicWiggleAnimation();
          
          _showVerifiedBadgePrompt();
        } else {
          // Stop periodic animation if user is not eligible
          _stopPeriodicWiggleAnimation();
        }
        } else {
          _showSnackBar('Failed to load verification status: ${response['message']}', isError: true);
          setState(() {
            _currentVerificationStatus = 'unverified'; // Fallback
          });
        }
      } catch (e) {
        print('VerificationScreen: ERROR in getVerificationStatus(): $e');
        _showSnackBar('Error loading verification status: $e', isError: true);
        setState(() {
          _currentVerificationStatus = 'unverified'; // Fallback
        });
      }
    } catch (e, stackTrace) {
      print('VerificationScreen: Error loading user or verification status: $e');
      print('VerificationScreen: Stack trace: $stackTrace');
      _showSnackBar('Error loading verification status: $e', isError: true);
      setState(() {
        _currentVerificationStatus = 'unverified'; // Fallback
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to safely convert any value to string
  String _safeStringValue(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    if (value is String) return value.isEmpty ? defaultValue : value;
    if (value is int || value is double || value is bool) return value.toString();
    return value.toString();
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

  // Function to launch the live photo capture screen for ID
  Future<void> _captureIdPhoto({required bool isFront}) async {
    // Check if type of identification is selected first
    if (_selectedIdType == null) {
      _showSnackBar('Please select type of identification first.', isError: true);
      return;
    }

    final XFile? capturedImage = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LivePhotoCaptureScreen()), // Reusing LivePhotoCaptureScreen for ID
    );

    if (capturedImage != null) {
      final fileSize = await capturedImage.length();
      if (fileSize > 1 * 1024 * 1024) {
        _showSnackBar('Image size exceeds 1MB. Please choose a smaller image.', isError: true);
        return;
      }
      setState(() {
        if (isFront) {
          _idPhotoFront = capturedImage;
        } else {
          _idPhotoBack = capturedImage;
        }
      });
    }
  }
  Future<void> _capturePhoto({required Function(XFile) onCaptured}) async {
    final XFile? capturedImage = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LivePhotoCaptureScreen()),
    );

    if (capturedImage != null) {
      final fileSize = await capturedImage.length();
      if (fileSize > 1 * 1024 * 1024) { // 1 MB limit
        _showSnackBar('Image size exceeds 1MB. Please choose a smaller image.', isError: true);
        return;
      }
      onCaptured(capturedImage);
    }
  }

  // NEW: Function to capture Barangay Clearance photo
  Future<void> _captureBrgyClearancePhoto() async {
    // Check if type of identification is selected first
    if (_selectedIdType == null) {
      _showSnackBar('Please select type of identification first.', isError: true);
      return;
    }

    await _capturePhoto(onCaptured: (image) {
      setState(() {
        _brgyClearancePhoto = image;
      });
    });
  }

  // Helper function to check if all verification requirements are completed
  bool _areAllRequirementsCompleted() {
    return _selectedIdType != null &&
           _idPhotoFront != null &&
           _idPhotoBack != null &&
           _brgyClearancePhoto != null &&
           _confirmIdBelongsToUser == true;
  }

  // NEW: Method to trigger wiggle animation for Get Badge button
  void _triggerWiggleAnimation() {
    setState(() {
      _isWiggleAnimating = true;
    });
    
    // Stop animation after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isWiggleAnimating = false;
        });
      }
    });
  }

  // NEW: Method to trigger wiggle animation for dialog button
  void _triggerDialogButtonWiggle(StateSetter? setDialogState) {
    setState(() {
      _isDialogButtonWiggling = true;
    });
    
    // Also update dialog state if callback is provided
    setDialogState?.call(() {
      // This will trigger a rebuild of the dialog
    });
    
    // Stop animation after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isDialogButtonWiggling = false;
        });
        // Also update dialog state if callback is provided
        setDialogState?.call(() {
          // This will trigger a rebuild of the dialog
        });
      }
    });
  }

  // FIXED: Method to show the "Want to have Verified Badge?" prompt
  Future<void> _showVerifiedBadgePrompt() async {
    if (_currentUser == null || !_isIdVerified || _isBadgeAcquired) {
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            // Create animation controller for the button wiggle
            late AnimationController _buttonAnimationController;
            late Animation<double> _buttonWiggleAnimation;
            
            // Initialize animation controller
            _buttonAnimationController = AnimationController(
              vsync: Navigator.of(context),
              duration: const Duration(milliseconds: 200), // Faster wiggle
            );

            _buttonWiggleAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
              CurvedAnimation(
                parent: _buttonAnimationController,
                curve: Curves.easeInOut,
              ),
            );

            // Start animation after dialog appears
            Future.delayed(const Duration(milliseconds: 500), () {
              _buttonAnimationController.repeat(reverse: true);
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Want to have Verified Badge?', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Constants.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'In both ASAP and public listings, the platform will show you first to the lister.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Constants.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Increase your chances of being chosen - listers can see your verified badge and feel safer choosing you.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _buttonWiggleAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_buttonWiggleAnimation.value * 10.0, 0), // 10 pixels left-right wiggle
                          child: ElevatedButton(
                            onPressed: () {
                              _buttonAnimationController.stop();
                              Navigator.of(dialogContext).pop(); // Close this dialog
                              _stopPeriodicWiggleAnimation(); // Stop periodic animation
                              // Navigate to the payment screen
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const VerifiedBadgePaymentScreen()),
                              ).then((_) async {
                                // After returning from payment screen, reload user status
                                await _loadUserAndVerificationStatus();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Column(
                              children: [
                                Text('Yes! I\'d like to have', style: TextStyle(fontSize: 16)),
                                Text('only for P299/mo', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        _buttonAnimationController.stop();
                        Navigator.of(dialogContext).pop();
                        _showSnackBar('You chose not to get the Verified Badge.', isError: false);
                        _showFinalDetailsSentDialog(); // Still show final dialog
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'No. I want to be recommended last',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Method to show the final "Details sent!" dialog
  Future<void> _showFinalDetailsSentDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Details sent!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Our team will review your info first, then we\'ll notify you. Verification usually takes 1-3 days.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to profile settings or dashboard
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('OK!', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // Function to handle the "Next" button submission (for ID photos)
  Future<void> _submitIdPhotos() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in. Cannot submit verification.', isError: true);
      return;
    }

    // Check ALL requirements first - if ANY is missing, show error and return immediately
    // Requirement 1: Type of identification selected
    if (_selectedIdType == null) {
      _showSnackBar('Please select an ID Type.', isError: true);
      return;
    }

    // Requirement 2: Front ID photo uploaded
    if (_idPhotoFront == null) {
      _showSnackBar('Please capture front ID photo.', isError: true);
      return;
    }

    // Requirement 3: Back ID photo uploaded
    if (_idPhotoBack == null) {
      _showSnackBar('Please capture back ID photo.', isError: true);
      return;
    }

    // Requirement 4: Brgy clearance uploaded
    if (_brgyClearancePhoto == null) {
      _showSnackBar('Please upload your Barangay Clearance photo.', isError: true);
      return;
    }

    // Requirement 5: ID ownership confirmed
    if (_confirmIdBelongsToUser == null || _confirmIdBelongsToUser != true) {
      _showSnackBar('Please confirm ID ownership.', isError: true);
      return;
    }

    // ALL 5 requirements are completed - now show the modal
    if (mounted) {
      final modalResult = await _showVerifiedBadgeModal();

      // Handle modal result
      if (modalResult == 'yes') {
        // User wants verified badge - this is handled in the modal function
        return;
      } else if (modalResult == 'no') {
        // User doesn't want verified badge - proceed to face verification
        await _performIdSubmission();
      }
    }
  }

  // Separate function to handle the actual ID submission
  Future<void> _performIdSubmission() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _verificationService.submitIdVerification(
      userId: _currentUser!.id!,
      idType: _selectedIdType!,
      idPhotoFrontPath: _idPhotoFront!.path,
      idPhotoBackPath: _idPhotoBack!.path,
      brgyClearancePhotoPath: _brgyClearancePhoto!.path,
      confirmation: _confirmIdBelongsToUser!,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar(response['message'] ?? 'ID photos submitted successfully!');
      // Navigate to face verification after successful submission
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const FaceVerificationScreen()),
        ).then((_) => _loadUserAndVerificationStatus());
      }
    } else {
      _showSnackBar('ID submission failed: ${response['message']}', isError: true);
    }
  }

  // NEW: Show verified badge modal before submission
  Future<String?> _showVerifiedBadgeModal() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext context) {
        return _buildVerifiedBadgeModal();
      },
    );

    if (result == 'yes') {
      // User wants verified badge - navigate to payment first
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const VerifiedBadgePaymentScreen()),
        ).then((_) => _loadUserAndVerificationStatus());
      }
    }
    // If result is 'no', just return it - the calling function will handle it

    return result;
  }

  // NEW: Method to start periodic wiggle animation
  void _startPeriodicWiggleAnimation() {
    _wiggleTimer?.cancel(); // Cancel any existing timer
    _wiggleTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _isIdVerified && !_isBadgeAcquired) {
        setState(() {
          _isWiggleAnimating = true;
        });
        
        // Stop animation after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _isWiggleAnimating = false;
            });
          }
        });
      } else {
        timer.cancel(); // Stop timer if conditions are no longer met
      }
    });
  }

  // NEW: Method to stop periodic wiggle animation
  void _stopPeriodicWiggleAnimation() {
    _wiggleTimer?.cancel();
    _wiggleTimer = null;
  }

  // NEW: Method to start periodic dialog button wiggle animation
  void _startDialogButtonWiggleAnimation(StateSetter? setDialogState) {
    _dialogButtonTimer?.cancel(); // Cancel any existing timer
    _dialogButtonTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _isDialogButtonWiggling = true;
        });
        
        // Stop animation after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _isDialogButtonWiggling = false;
            });
          }
        });
      } else {
        timer.cancel(); // Stop timer if widget is disposed
      }
    });
  }

  // NEW: Method to stop periodic dialog button wiggle animation
  void _stopDialogButtonWiggleAnimation() {
    _dialogButtonTimer?.cancel();
    _dialogButtonTimer = null;
  }

  // NEW: Build verified badge modal widget
  Widget _buildVerifiedBadgeModal() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue checkmark icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4), // Google Blue
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Get Your Verified Badge',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Benefits list
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Be featured first — Appear at the top of listings in both ASAP and public search results.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Boost your credibility — Verified users are more likely to be chosen, giving listers greater confidence and peace of mind.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Yes button with wiggle animation
              SizedBox(
                width: double.infinity,
                child: AnimatedWiggleButton(
                  onPressed: () {
                    Navigator.of(context).pop('yes');
                  },
                  isAnimating: true, // Always animate when modal is shown
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4), // Same blue as icon
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Yes! I\'d like to get verified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Price text
              const Text(
                '(only for P299/month)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // No button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop('no');
                },
                child: const Text(
                  'No thanks, continue with face verification',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String statusMessage;
    Color statusColor;
    IconData statusIcon;

    switch (_currentVerificationStatus) {
      case 'verified':
        statusMessage = 'You are verified!';
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle;
        break;
      case 'pending_id_review': // Now covers ID + Brgy Clearance review
        statusMessage = 'Documents submitted. Awaiting review.';
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.pending_actions;
        break;
      case 'pending_face_match':
        statusMessage = 'ID photos reviewed. Proceed to face verification.';
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.face;
        break;
      case 'rejected':
        statusMessage = 'Verification rejected. Please try again.';
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel;
        break;
      default: // 'unverified' or unknown
        statusMessage = 'Please submit your ID for verification.';
        statusColor = Colors.grey.shade700;
        statusIcon = Icons.info_outline;
        break;
    }
    final bool disableDocumentUpload = (_currentVerificationStatus != 'unverified' && _currentVerificationStatus != 'rejected');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Display (Badge-like UI)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusMessage,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (_isIdVerified && _currentVerificationStatus == 'verified' && _isBadgeAcquired)
                          Text(
                            'Verified Badge Acquired!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isIdVerified && !_isBadgeAcquired)
                    AnimatedWiggleButton(
                      onPressed: () {
                        _triggerWiggleAnimation();
                        _showVerifiedBadgePrompt();
                      },
                      isAnimating: _isWiggleAnimating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Get Badge'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Type of Identification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 8),
            // Horizontal scrollable ID Type buttons (replace Dropdown)
            SizedBox(
              height: 50, // Fixed height for the row of buttons
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _idTypes.length,
                itemBuilder: (context, index) {
                  final idType = _idTypes[index];
                  final isSelected = _selectedIdType == idType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      onPressed: _currentVerificationStatus == 'verified' ? null : () { // Disable if already verified
                        setState(() {
                          _selectedIdType = idType;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Constants.primaryColor : Colors.grey.shade200,
                        foregroundColor: isSelected ? Colors.white : Constants.textColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isSelected ? Constants.primaryColor : Colors.grey.shade400),
                        elevation: isSelected ? 4 : 1,
                        minimumSize: const Size(120, 50), // Minimum size for buttons
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(idType),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Upload your ID photos*',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _currentVerificationStatus == 'verified' ? null : () => _captureIdPhoto(isFront: true),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                      ),
                      child: _idPhotoFront == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text(
                            'ID Front',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const Text(
                            '1 MB max',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_idPhotoFront!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _currentVerificationStatus == 'verified' ? null : () => _captureIdPhoto(isFront: false),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                      ),
                      child: _idPhotoBack == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text(
                            'ID Back',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const Text(
                            '1 MB max',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_idPhotoBack!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // NEW: Upload Brgy. Clearance Section
            const Text(
              'Upload Brgy. Clearance*',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: disableDocumentUpload ? null : _captureBrgyClearancePhoto,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                ),
                child: _brgyClearancePhoto == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, size: 50, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Click here to upload',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                    const Text(
                      'Photo size: 1 MB max',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_brgyClearancePhoto!.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Do you confirm this ID belongs to you?*',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Constants.textColor),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Yes'),
                    value: true,
                    groupValue: _confirmIdBelongsToUser,
                    onChanged: _currentVerificationStatus == 'verified' ? null : (bool? value) {
                      setState(() {
                        _confirmIdBelongsToUser = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('No'),
                    value: false,
                    groupValue: _confirmIdBelongsToUser,
                    onChanged: _currentVerificationStatus == 'verified' ? null : (bool? value) {
                      setState(() {
                        _confirmIdBelongsToUser = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _currentVerificationStatus == 'verified' || _currentVerificationStatus == 'pending_id_review' || _currentVerificationStatus == 'pending_face_match')
                    ? null // Disable if loading or already submitted/verified/pending
                    : _submitIdPhotos, // Calls the submission for ID photos
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  _currentVerificationStatus == 'verified'
                      ? 'VERIFIED'
                      : _currentVerificationStatus == 'pending_id_review'
                      ? 'ID Submitted. Pending Review.'
                      : _currentVerificationStatus == 'pending_face_match'
                      ? 'Proceed to Face Verification'
                      : 'Next (Submit ID Photos)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
