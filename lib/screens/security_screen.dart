import 'package:flutter/material.dart';
import 'package:hanapp/utils/constants.dart' as Constants; // For colors
import 'package:hanapp/utils/auth_service.dart'; // For AuthService
import 'package:hanapp/models/user.dart'; // For User model
import 'package:hanapp/models/login_history_item.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  User? _currentUser; // To get the current user's ID
  bool _isLoading = false; // For the update password button
  bool _is2faEnabled = false; // Placeholder for 2FA status
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmNewPassword = false;
  List<LoginHistoryItem> _loginHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndHistory();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndHistory() async {
    await _loadCurrentUser();
    await _fetchLoginHistory();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await AuthService.getUser();
    if (_currentUser == null) {
      // If no user is found, navigate back to login
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
    setState(() {}); // Update UI to ensure _currentUser is set
  }

  Future<void> _fetchLoginHistory() async {
    if (_currentUser == null || _currentUser!.id == null) return;
    setState(() { _isLoadingHistory = true; });
    final history = await AuthService.fetchLoginHistory(_currentUser!.id);
    setState(() {
      _loginHistory = history;
      _isLoadingHistory = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
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

  Future<void> _changePassword() async {
    if (_currentUser == null || _currentUser!.id == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmNewPassword = _confirmNewPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) {
      _showSnackBar('All password fields are required.', isError: true);
      return;
    }
    if (newPassword != confirmNewPassword) {
      _showSnackBar('New password and confirm password do not match.', isError: true);
      return;
    }
    if (newPassword.length < 6) { // Example: minimum password length
      _showSnackBar('New password must be at least 6 characters long.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await _authService.changePassword(
      userId: _currentUser!.id!,
      currentPassword: currentPassword,
      newPassword: newPassword, oldPassword: '',
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      _showSnackBar('Password updated successfully!');
      // Clear password fields on success
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
    } else {
      _showSnackBar('Failed to update password: ${response['message']}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Change Password Section
            Text(
              'Change Password',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _currentPasswordController,
              labelText: 'Current Password',
              showPassword: _showCurrentPassword,
              onToggle: () {
                setState(() {
                  _showCurrentPassword = !_showCurrentPassword;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newPasswordController,
              labelText: 'New Password',
              showPassword: _showNewPassword,
              onToggle: () {
                setState(() {
                  _showNewPassword = !_showNewPassword;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmNewPasswordController,
              labelText: 'Confirm Password',
              showPassword: _showConfirmNewPassword,
              onToggle: () {
                setState(() {
                  _showConfirmNewPassword = !_showConfirmNewPassword;
                });
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Update Password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 2-Factor Authentication Section
            Text(
              '2-Factor Authentication',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.zero,
              child: ListTile(
                title: const Text('Enable 2FA'),
                trailing: Switch(
                  value: _is2faEnabled,
                  onChanged: (bool newValue) {
                    setState(() {
                      _is2faEnabled = newValue;
                    });
                    // TODO: Implement 2FA enable/disable logic via backend
                    _showSnackBar('2FA toggle (Not implemented yet)');
                  },
                  activeColor: Constants.primaryColor,
                ),
                onTap: () {
                  // Tapping the tile also triggers the switch
                  setState(() {
                    _is2faEnabled = !_is2faEnabled;
                  });
                  // TODO: Implement 2FA enable/disable logic via backend
                  _showSnackBar('2FA toggle (Not implemented yet)');
                },
              ),
            ),
            const SizedBox(height: 40),

            // Login History Section
            Text(
              'Login History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Constants.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _loginHistory.isEmpty
                    ? const Text('No login history found.')
                    : Column(
                        children: _loginHistory
                            .map((item) => _buildLoginHistoryItem(
                                  date: item.date,
                                  time: item.time,
                                  location: item.location,
                                  device: item.device,
                                ))
                            .toList(),
                      ),
          ],
        ),
      ),
    );
  }

  // Helper to build password text fields with toggle visibility
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  // Helper to build login history items
  Widget _buildLoginHistoryItem({
    required String date,
    required String time,
    required String location,
    required String device,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: $date',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: $time',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Location: $location',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Device: $device',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
