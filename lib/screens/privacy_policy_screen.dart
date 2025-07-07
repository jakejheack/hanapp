import 'package:flutter/material.dart';
import 'package:hanapp/models/app_setting.dart';
import 'package:hanapp/services/setting_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  AppSetting? _privacyPolicy;
  bool _isLoading = true;
  String? _errorMessage;
  final SettingService _settingService = SettingService();

  @override
  void initState() {
    super.initState();
    _fetchPrivacyPolicy();
  }

  Future<void> _fetchPrivacyPolicy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the specific helper method for Privacy Policy
      final response = await _settingService.getPrivacyPolicy();
      if (response['success']) {
        setState(() {
          _privacyPolicy = response['data'];
        });
      } else {
        _errorMessage = response['message'] ?? 'Failed to load Privacy Policy.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      debugPrint('Error fetching Privacy Policy: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 50),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchPrivacyPolicy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _privacyPolicy == null || _privacyPolicy!.description.isEmpty
          ? Center(
        child: Text(
          'Privacy Policy content is not available.',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: HtmlWidget(
          _privacyPolicy!.description,
          textStyle: const TextStyle(fontSize: 15, height: 1.5),
          enableCaching: true,
        ),
      ),
    );
  }
} 