import 'package:flutter/material.dart';
import 'package:hanapp/screens/components/custom_button.dart';
import 'package:hanapp/widgets/date_picker_field.dart';
import 'package:intl/intl.dart';

class SignupScreen2 extends StatefulWidget {
  const SignupScreen2({super.key});

  @override
  State<SignupScreen2> createState() => _SignupScreen2State();
}

class _SignupScreen2State extends State<SignupScreen2> {
  DateTime? _selectedDate;
  final TextEditingController _dateController = TextEditingController();

  void _nextStep(Map<String, dynamic> previousData) {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birth date.')),
      );
      return;
    }

    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    Navigator.of(context).pushNamed(
      '/signup3',
      arguments: {
        ...previousData,
        'birth_date': formattedDate,
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
            DatePickerField(
              controller: _dateController,
              labelText: 'Birth Date',
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
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
          ],
        ),
      ),
    );
  }
}