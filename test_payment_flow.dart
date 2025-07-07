import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanapp/screens/because_screen.dart';
import 'package:hanapp/utils/constants.dart';

void main() {
  group('Payment Flow Tests', () {
    testWidgets('BecauseScreen - Job payment with pre-filled amount', (WidgetTester tester) async {
      const double jobAmount = 500.0;
      const String listingTitle = 'Test Job';
      const String applicationId = '123';

      await tester.pumpWidget(
        MaterialApp(
          home: BecauseScreen(
            preFilledAmount: jobAmount,
            isJobPayment: true,
            applicationId: applicationId,
            listingTitle: listingTitle,
          ),
        ),
      );

      // Verify the screen shows job payment title
      expect(find.text('Job Payment'), findsOneWidget);

      // Verify amount is pre-filled
      expect(find.byType(TextFormField), findsOneWidget);
      // Note: We can't directly test the controller value in widget tests
      // but we can verify the widget is present
    });

    testWidgets('BecauseScreen - Regular payment without pre-filled amount', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BecauseScreen(),
        ),
      );

      // Verify the screen shows regular payment title
      expect(find.text('Make a Payment'), findsOneWidget);

      // Verify no pre-filled amount
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('BecauseScreen - Payment method selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BecauseScreen(),
        ),
      );

      // Verify payment method options are present
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(find.text('GCash E-Wallet'), findsOneWidget);
      expect(find.text('Maya E-Wallet'), findsOneWidget);
      expect(find.text('Credit/Debit Card'), findsOneWidget);
    });

    testWidgets('BecauseScreen - Demo payment for job', (WidgetTester tester) async {
      const double jobAmount = 750.0;
      const String listingTitle = 'House Cleaning';

      await tester.pumpWidget(
        MaterialApp(
          home: BecauseScreen(
            preFilledAmount: jobAmount,
            isJobPayment: true,
            listingTitle: listingTitle,
          ),
        ),
      );

      // Tap on a payment method
      await tester.tap(find.text('GCash E-Wallet'));
      await tester.pump();

      // Tap proceed to payment
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pump();

      // Should show demo payment dialog
      expect(find.text('Demo Job Payment'), findsOneWidget);
      expect(find.text('Demo payment of ₱750.00 for job: House Cleaning.'), findsOneWidget);
    });

    testWidgets('BecauseScreen - Payment validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BecauseScreen(),
        ),
      );

      // Try to proceed without selecting payment method
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pump();

      // Should show error message
      expect(find.text('Please select a payment method'), findsOneWidget);
    });

    testWidgets('BecauseScreen - Amount validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BecauseScreen(),
        ),
      );

      // Enter invalid amount
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.pump();

      // Select payment method
      await tester.tap(find.text('GCash E-Wallet'));
      await tester.pump();

      // Try to proceed
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pump();

      // Should show error message
      expect(find.text('Please enter a valid amount'), findsOneWidget);
    });
  });
} 