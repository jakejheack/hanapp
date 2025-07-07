import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/screens/auth/password_reset_new_password_screen.dart';

class PasswordResetCodeScreen extends StatefulWidget {
  final String email;

  const PasswordResetCodeScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<PasswordResetCodeScreen> createState() => _PasswordResetCodeScreenState();
}

class _PasswordResetCodeScreenState extends State<PasswordResetCodeScreen> {
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _resendTimerSeconds = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupCodeInputs();
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _setupCodeInputs() {
    for (int i = 0; i < 6; i++) {
      _codeControllers[i].addListener(() {
        if (_codeControllers[i].text.length == 1 && i < 5) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  void _startResendTimer() {
    _resendTimerSeconds = 60;
    _canResend = false;
    _timer?.cancel();
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

  String _getCode() {
    return _codeControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    final code = _getCode();
    if (code.length != 6) {
      _showSnackBar('Please enter the complete 6-digit code', isError: true);
      return;
    }

    setState(() { _isLoading = true; });
    
    try {
      final response = await AuthService.verifyPasswordResetCode(widget.email, code);
      setState(() { _isLoading = false; });
      
      if (response['success'] == true) {
        // Navigate to new password screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PasswordResetNewPasswordScreen(
              email: widget.email,
              code: code,
            ),
          ),
        );
      } else {
        _showSnackBar(response['message'] ?? 'Invalid code', isError: true);
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _showSnackBar('Network error occurred', isError: true);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    
    setState(() { _isLoading = true; });
    
    try {
      final response = await AuthService.sendPasswordResetEmail(widget.email);
      setState(() { _isLoading = false; });
      
      if (response['success'] == true) {
        _showSnackBar('New code sent to your email');
        _startResendTimer();
        // Clear the code fields
        for (var controller in _codeControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      } else {
        _showSnackBar(response['message'] ?? 'Failed to resend code', isError: true);
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _showSnackBar('Network error occurred', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Code'),
        backgroundColor: Constants.primaryColor,
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
                const Text(
                  'Enter Verification Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Constants.primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a 6-digit code to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 32),
                
                // Code input fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) => 
                    SizedBox(
                      width: 45,
                      child: TextFormField(
                        controller: _codeControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        decoration: InputDecoration(
                          counterText: "",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Resend code button
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend ? 'Resend Code' : 'Resend code in: $_resendTimerSeconds',
                      style: TextStyle(
                        color: _canResend ? Constants.primaryColor : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Verify button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Verify Code',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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