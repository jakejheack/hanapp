import 'package:flutter/material.dart';
import 'package:hanapp/models/app_setting.dart';
import 'package:hanapp/services/setting_service.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  AppSetting? _termsAndConditions;
  bool _isLoading = true;
  String? _errorMessage;
  final SettingService _settingService = SettingService();

  @override
  void initState() {
    super.initState();
    _fetchTermsAndConditions();
  }

  Future<void> _fetchTermsAndConditions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _settingService.getTermsAndConditions();
      if (response['success']) {
        setState(() {
          _termsAndConditions = response['data'];
        });
      } else {
        _errorMessage = response['message'] ?? 'Failed to load Terms and Conditions.';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      debugPrint('Error fetching Terms and Conditions: $e');
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
        title: const Text('Terms & Conditions'),
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
                onPressed: _fetchTermsAndConditions,
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
          : _termsAndConditions == null || _termsAndConditions!.description.isEmpty
          ? Center(
        child: Text(
          'Terms and Conditions content is not available.',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: HtmlWidget(
          _termsAndConditions!.description,
          // You can configure various options for HTML rendering here
          // e.g., textStyle: const TextStyle(fontSize: 15, color: Constants.textColor),
          // onUnsupportedElement: (element) => ... handle unsupported tags
          // renderMode: RenderMode.column, // or RenderMode.listView for long content
          textStyle: const TextStyle(fontSize: 15, height: 1.5),
          enableCaching: true, // Enable caching for better performance
        ),
      ),
    );
  }
} 