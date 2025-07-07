import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'package:hanapp/utils/auth_service.dart'; // Ensure correct path
import 'package:hanapp/screens/auth/login_screen.dart'; // Navigate to login after verification

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _resendTimerSeconds = 60; // Initial timer value
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimerSeconds = 60;
    _canResend = false;
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _resendTimerSeconds--;
        });
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _verifyEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final response = await AuthService.verifyEmail(email: widget.email, code: _otpController.text.trim());

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        _showSnackBar(response['message']);
        // Navigate to login screen after successful verification
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        _showSnackBar('Verification failed: ${response['message']}', isError: true);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_canResend) {
      setState(() {
        _isLoading = true;
        _canResend = false; // Disable resend button immediately
      });

      final response = await AuthService.resendVerificationCode(widget.email);

      setState(() {
        _isLoading = false;
      });

      if (response['success']) {
        _showSnackBar(response['message']);
        _startResendTimer(); // Restart timer
      } else {
        _showSnackBar('Resend failed: ${response['message']}', isError: true);
        setState(() {
          _canResend = true; // Re-enable resend if there was an error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: const Color(0xFF141CC9),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/hanapp_logo.jpg', // Your app logo
                  height: 80,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Email Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF141CC9)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the OTP code sent to your email (${widget.email}).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Enter OTP Code',
                    hintText: 'XXXXXX',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: "", // Hide the default counter
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
                      return 'Please enter a valid 6-digit code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend ? 'Resend Code' : 'Resend code in: $_resendTimerSeconds',
                      style: TextStyle(
                        color: _canResend ? const Color(0xFF141CC9) : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141CC9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
