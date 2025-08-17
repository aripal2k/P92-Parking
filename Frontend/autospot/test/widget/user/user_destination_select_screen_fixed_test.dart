import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/user/userDestinationSelect_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('DestinationSelectScreen Fixed Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('shows destinations after loading completes', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for the 5-second timer to complete
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Should show destinations
      expect(find.text('Westfield Sydney'), findsOneWidget);
      expect(find.text('Building Entrance (BE1)'), findsOneWidget);
    });

    testWidgets('can select destination and shows check icon', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading to complete
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Select Exit (X1)
      await tester.tap(find.text('Exit (X1)'));
      await tester.pump();
      
      // Should show check icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows error when no entrance data', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for initial loading to complete
      await tester.pump();
      
      // The widget shows error immediately when no entrance data
      expect(find.text('No entrance data found. Please scan a valid entrance QR code.'), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
      
      // Wait for any pending timers
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
    });

    testWidgets('displays entrance ID correctly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E123',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      expect(find.text('ID: E123'), findsOneWidget);
    });

    testWidgets('saves destination when selected and button pressed', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
        'user_email': 'test@example.com',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Select first destination (Westfield Sydney)
      await tester.tap(find.text('Westfield Sydney'));
      await tester.pump();
      
      // Press button
      await tester.tap(find.text('Find Best Parking Spot'));
      await tester.pump();
      
      // Check saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_destination'), 'Westfield Sydney');
      
      // Wait for API timeout
      await tester.pump(const Duration(seconds: 15, milliseconds: 100));
    });

    testWidgets('shows snackbar when no destination selected', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Press button without selecting
      await tester.tap(find.text('Find Best Parking Spot'));
      await tester.pump();
      await tester.pump();
      
      expect(find.text('Please select a destination'), findsOneWidget);
    });

    testWidgets('back button exists in app bar', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      
      // Wait for timer
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
    });

    testWidgets('has correct theme colors', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
      
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFA3DB94));
      
      // Wait for timer
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
    });

    testWidgets('card changes color when selected', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Select first destination
      await tester.tap(find.text('Westfield Sydney'));
      await tester.pump();
      
      // Check card color changed
      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.color, const Color(0xFFA3DB94));
      expect(card.elevation, 4);
    });

    testWidgets('handles missing user email error', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
        // No user_email
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Select and process
      await tester.tap(find.text('Westfield Sydney'));
      await tester.pump();
      await tester.tap(find.text('Find Best Parking Spot'));
      await tester.pump();
      
      // Should show error eventually
      await tester.pump(const Duration(seconds: 15, milliseconds: 100));
      
      // Error dialog should appear
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('button has correct styling', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      final button = find.widgetWithText(ElevatedButton, 'Find Best Parking Spot');
      expect(button, findsOneWidget);
      
      final buttonWidget = tester.widget<ElevatedButton>(button);
      expect(buttonWidget.style?.backgroundColor?.resolve({}), const Color(0xFFA3DB94));
    });

    testWidgets('destination list is scrollable', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('uses demo data when API fails', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
        'user_email': 'test@example.com',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Select Exit (X1)
      await tester.tap(find.text('Exit (X1)'));
      await tester.pump();
      await tester.tap(find.text('Find Best Parking Spot'));
      await tester.pump();
      
      // Wait for API to fail
      await tester.pump(const Duration(seconds: 15, milliseconds: 100));
      
      // Should show error dialog
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Use Demo Data'), findsOneWidget);
      
      // Use demo data
      await tester.tap(find.text('Use Demo Data'));
      await tester.pump();
      
      // Should save demo data
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('allocated_spot_id'), '1D');
      
      // Wait for navigation
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('entrance container has proper styling', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Find container with entrance info
      final containerFinder = find.ancestor(
        of: find.text('Entrance Detected'),
        matching: find.byType(Container),
      ).first;
      
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('handles cancel in error dialog', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'entrance_id': 'E001',
        'user_email': 'test@example.com',
      });

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const DestinationSelectScreen()),
      );
      
      // Wait for loading
      await tester.pump(const Duration(seconds: 5, milliseconds: 100));
      
      // Select and process
      await tester.tap(find.text('Westfield Sydney'));
      await tester.pump();
      await tester.tap(find.text('Find Best Parking Spot'));
      await tester.pump();
      
      // Wait for error
      await tester.pump(const Duration(seconds: 15, milliseconds: 100));
      
      // Press Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      // Dialog should be closed
      expect(find.text('Error'), findsNothing);
    });
  });
}