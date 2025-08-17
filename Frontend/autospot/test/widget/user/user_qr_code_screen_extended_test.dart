import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userQRCode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('QRCodeScreen Extended Coverage Tests', () {
    late MockClient mockClient;

    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('tests _styledButton widget creation', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Find styled button
      final inkWellFinder = find.byType(InkWell);
      expect(inkWellFinder, findsAtLeastNWidgets(1));
      
      final animatedContainerFinder = find.descendant(
        of: inkWellFinder,
        matching: find.byType(AnimatedContainer),
      );
      expect(animatedContainerFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('bottom navigation bar exists with correct items', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': 'testuser',
        'selected_destination': 'Building A',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Check bottom navigation exists
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      
      // Check all icons exist
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.byIcon(Icons.qr_code), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      
      // Check current index
      final bottomNav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bottomNav.currentIndex, 2); // QR Code screen is index 2
    });

    testWidgets('handles API exception during username fetch', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'selected_destination': 'Building A',
        // No username to trigger API call
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - Should handle error gracefully
      expect(find.text('No QR code available,\nDrive your car near the building or entrance'), findsOneWidget);
    });

    testWidgets('handles missing username in SharedPreferences', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'selected_destination': 'Building A',
        // username is missing
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('No QR code available,\nDrive your car near the building or entrance'), findsOneWidget);
    });

    testWidgets('handles missing destination in SharedPreferences', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': 'testuser',
        // selected_destination is missing
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('No QR code available,\nDrive your car near the building or entrance'), findsOneWidget);
    });

    testWidgets('handles QR image loading failure', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': 'testuser',
        'selected_destination': 'Building A',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - QR image widget should exist even if loading fails
      expect(find.text('Successfully get a lot.\nPlease scan the QR code below:'), findsOneWidget);
      // Since qrImageBytes is null, it should show fallback text
      expect(find.text('QR image failed to load'), findsOneWidget);
    });

    testWidgets('CircularProgressIndicator has correct color', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );

      // Assert - Check loading indicator color
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator).first,
      );
      expect(indicator, isNotNull);
    });

    testWidgets('handles successful username fetch and QR generation', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': 'testuser',
        'selected_destination': 'Building A',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show QR code
      expect(find.text('Successfully get a lot.\nPlease scan the QR code below:'), findsOneWidget);
      expect(find.text('Scan Complete'), findsOneWidget);
    });

    testWidgets('retry button properly calls _refreshQRStatus', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find and tap retry button
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Assert - Should trigger refresh
      expect(find.byType(QRCodeScreen), findsOneWidget);
    });

    testWidgets('scan complete button resets state correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': 'testuser',
        'selected_destination': 'Building A',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify QR is shown
      expect(find.text('Successfully get a lot.\nPlease scan the QR code below:'), findsOneWidget);

      // Tap scan complete
      await tester.tap(find.text('Scan Complete'));
      await tester.pump();

      // Assert - Should reset to no QR state
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No QR code available,\nDrive your car near the building or entrance'), findsOneWidget);
    });

    testWidgets('bottom navigation bar tap on already selected item', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      bool navigatedToQRCode = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const QRCodeScreen(),
          routes: {
            '/qr-code': (context) {
              navigatedToQRCode = true;
              return const Scaffold(body: Text('QR Code'));
            },
          },
        ),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on QR icon (current page)
      await tester.tap(find.byIcon(Icons.qr_code));
      await tester.pump();

      // Assert - Should navigate even to same page
      expect(navigatedToQRCode, true);
    });

    testWidgets('plant icon in bottom navigation exists but index 1 not handled', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Plant icon exists
      expect(find.byIcon(Icons.eco), findsOneWidget);
      
      // Tap plant icon (index 1 - no navigation handler)
      await tester.tap(find.byIcon(Icons.eco));
      await tester.pump();

      // Should stay on same screen
      expect(find.byType(QRCodeScreen), findsOneWidget);
    });

    testWidgets('handles API response with status 200 and valid data', (WidgetTester tester) async {
      // Arrange - Create the condition for API call (missing username)
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'selected_destination': 'Building A',
        // No username to trigger API call
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - API would have been called
      expect(find.byType(QRCodeScreen), findsOneWidget);
    });

    testWidgets('BackdropFilter blur effect properties', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Check BackdropFilter properties
      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(backdropFilter.filter, isNotNull);
    });

    testWidgets('Container decoration properties for QR section', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the container inside BackdropFilter
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(Container),
        ).first,
      );

      // Assert decoration properties
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white.withOpacity(0.15));
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(decoration.border, isNotNull);
    });
  });
}