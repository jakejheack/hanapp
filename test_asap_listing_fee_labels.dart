import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanapp/screens/lister/asap_listing_form_screen.dart';

void main() {
  group('ASAP Listing Form Fee Labels', () {
    testWidgets('should display correct fee labels', (WidgetTester tester) async {
      // Build the ASAP listing form
      await tester.pumpWidget(
        MaterialApp(
          home: const AsapListingFormScreen(),
        ),
      );

      // Wait for the widget to be fully built
      await tester.pumpAndSettle();

      // Verify the input field label is "Doer Fee *"
      expect(find.text('Doer Fee *'), findsOneWidget);

      // Verify the fee display section shows correct labels
      expect(find.text('Doer Fee'), findsOneWidget);
      expect(find.text('Transaction Fee'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);

      // Verify the payment details section title
      expect(find.text('Payment Details'), findsOneWidget);
    });

    testWidgets('should show correct validation messages for doer fee', (WidgetTester tester) async {
      // Build the ASAP listing form
      await tester.pumpWidget(
        MaterialApp(
          home: const AsapListingFormScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the doer fee text field
      final doerFeeField = find.byType(TextFormField).first;
      
      // Enter an invalid value (less than 500)
      await tester.enterText(doerFeeField, '100');
      await tester.pump();

      // Trigger validation by tapping outside
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      // Verify the validation message mentions "doer fee"
      expect(find.text('Minimum doer fee is Php 500.00'), findsOneWidget);
    });
  });
} 