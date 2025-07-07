import 'package:flutter/material.dart';
import 'package:hanapp/screens/components/custom_button.dart';

class SignupScreen3 extends StatefulWidget {
  const SignupScreen3({super.key});

  @override
  State<SignupScreen3> createState() => _SignupScreen3State();
}

class _SignupScreen3State extends State<SignupScreen3> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _cityProvinceController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  // Temporary function to show Facebook coming soon message
  void _showFacebookComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Facebook Signup coming soon! Please use email signup for now.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _nextStep(Map<String, dynamic> previousData) {
    if (_addressController.text.isEmpty ||
        _barangayController.text.isEmpty ||
        _cityProvinceController.text.isEmpty ||
        _countryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all address fields.')),
      );
      return;
    }

    final String fullAddress =
        '${_addressController.text}, ${_barangayController.text}, '
        '${_cityProvinceController.text}, ${_countryController.text}';

    Navigator.of(context).pushNamed(
      '/signup4',
      arguments: {
        ...previousData,
        'address_details': fullAddress,
      },
    );
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
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _barangayController,
              decoration: const InputDecoration(
                labelText: 'Barangay',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityProvinceController,
              decoration: const InputDecoration(
                labelText: 'City/Province',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Continue',
              onPressed: () => _nextStep(previousData),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              child: const Text('Already have a HANAPP account? Log in here'),
            ),
            const SizedBox(height: 24),
            // Social signup buttons (placeholders)
            CustomButton(
              text: 'Signup with Facebook',
              onPressed: _showFacebookComingSoonMessage,
              color: Colors.blue.shade800,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Signup with Google',
              onPressed: () { /* TODO: Google signup */ },
              color: Colors.red.shade800,
            ),
          ],
        ),
      ),
    );
  }
}