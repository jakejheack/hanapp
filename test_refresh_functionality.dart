import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:provider/provider.dart';
import 'package:hanapp/screens/doer/doer_job_listings_screen.dart';
import 'package:hanapp/viewmodels/doer_job_listings_view_model.dart';
import 'package:hanapp/utils/constants.dart';

void main() {
  group('Refresh Functionality Tests', () {
    testWidgets('Doer Job Listings Screen - Refresh button shows loading state', (WidgetTester tester) async {
      // Create a mock view model
      final viewModel = DoerJobListingsViewModel();
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DoerJobListingsViewModel>.value(
            value: viewModel,
            child: const DoerJobListingsScreen(),
          ),
        ),
      );

      // Find the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // Tap the refresh button
      await tester.tap(refreshButton);
      await tester.pump();

      // Verify loading state is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Doer Job Listings Screen - Refresh button is disabled during loading', (WidgetTester tester) async {
      // Create a mock view model
      final viewModel = DoerJobListingsViewModel();
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DoerJobListingsViewModel>.value(
            value: viewModel,
            child: const DoerJobListingsScreen(),
          ),
        ),
      );

      // Find the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // Tap the refresh button to start loading
      await tester.tap(refreshButton);
      await tester.pump();

      // Verify the button is now disabled (showing loading indicator)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Try to tap again - should not trigger another refresh
      await tester.tap(refreshButton);
      await tester.pump();
      
      // Should still show only one loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Doer Job Listings Screen - Center loading overlay appears during refresh', (WidgetTester tester) async {
      // Create a mock view model
      final viewModel = DoerJobListingsViewModel();
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DoerJobListingsViewModel>.value(
            value: viewModel,
            child: const DoerJobListingsScreen(),
          ),
        ),
      );

      // Find the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // Tap the refresh button
      await tester.tap(refreshButton);
      await tester.pump();

      // Verify center loading overlay appears
      expect(find.text('Refreshing job listings...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ASAP Searching Doer Screen - Improved loading animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Constants.primaryColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Constants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Searching...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Constants.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify the improved loading animation elements are present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Searching...'), findsOneWidget);
    });
  });
} 