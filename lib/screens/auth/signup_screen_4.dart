import 'package:flutter/material.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/utils/auth_service.dart';

class SignupScreen4 extends StatefulWidget {
  const SignupScreen4({super.key});

  @override
  State<SignupScreen4> createState() => _SignupScreen4State();
}

class _SignupScreen4State extends State<SignupScreen4> {
  String? _selectedGender;
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _register(Map<String, dynamic> previousData) async {
    if (_selectedGender == null ||
        _contactNumberController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackBar('Please fill all fields.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // final response = await _authService.registerUser(
    //   full_name: previousData['full_name'],
    //   first_name: previousData['first_name'],
    //   last_name: previousData['last_name'],
    //   birth_date: previousData['birth_date'],
    //   address_details: previousData['address_details'],
    //   gender: _selectedGender!,
    //   contact_number: _contactNumberController.text,
    //   email: _emailController.text,
    //   password: _passwordController.text,
    // );

    setState(() {
      _isLoading = false;
    });

    // if (response['success']) {
    //   _showSnackBar(response['message']);
    //   Navigator.of(context).pushNamed(
    //     '/email_verification',
    //     arguments: {'email': _emailController.text},
    //   );
    // } else {
    //   _showSnackBar(response['message'], isError: true);
    // }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> previousData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SIGN UP'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: <String>['Male', 'Female', 'Other']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contactNumberController,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : CustomButton(
              text: 'Continue',
              onPressed: () => _register(previousData),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              child: const Text('Already have a HANAPP account? Log in here'),
            ),
          ],
        ),
      ),
    );
  }
}