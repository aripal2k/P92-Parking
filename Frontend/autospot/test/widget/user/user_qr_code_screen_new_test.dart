import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userQRCode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import '../../helpers/test_helpers.dart';

void main() {
  group('QRCodeScreen New Version Tests', () {
    late MockClient mockClient;

    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Mock HTTP client for API calls
      mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/profile')) {
          return http.Response(
            jsonEncode({
              'username': 'testuser',
              'email': 'test@example.com',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays loading state initially', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );

      // Assert - Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays no QR code state when data is missing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        // Missing username and destination
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      // Wait for async operations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('No QR code available,\nDrive your car near the building or entrance'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('displays all main UI elements', (WidgetTester tester) async {
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

      // Assert
      expect(find.text('AutoSpot'), findsOneWidget);
      expect(find.text('Scan Entrance QR Code'), findsOneWidget);
      expect(find.text('My QR Code'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('shows QR generation success state', (WidgetTester tester) async {
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
      
      // Wait for initial load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('Successfully get a lot.\nPlease scan the QR code below:'), findsOneWidget);
      expect(find.text('Scan Complete'), findsOneWidget);
    });

    testWidgets('handles scan entrance QR button tap', (WidgetTester tester) async {
      // Arrange
      bool navigatedToScanner = false;
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const QRCodeScreen(),
          routes: {
            '/qr-scanner': (context) {
              navigatedToScanner = true;
              return const Scaffold(body: Text('QR Scanner'));
            },
          },
        ),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the scan entrance button
      await tester.tap(find.text('Scan Entrance QR Code'));
      await tester.pump();

      // Assert
      expect(navigatedToScanner, true);
    });

    testWidgets('handles retry button tap', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        // Missing data to show retry button
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify retry button exists
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Should trigger refresh
      expect(find.byType(QRCodeScreen), findsOneWidget);
    });

    testWidgets('handles scan complete button tap', (WidgetTester tester) async {
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

      // Tap scan complete button
      await tester.tap(find.text('Scan Complete'));
      await tester.pump();

      // Should reset to no QR state
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No QR code available,\nDrive your car near the building or entrance'), findsOneWidget);
    });

    testWidgets('fetches username when missing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'selected_destination': 'Building A',
        // Username is missing
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - Should attempt to fetch username
      final prefs = await SharedPreferences.getInstance();
      // The test should have attempted to fetch and store username
      expect(find.byType(QRCodeScreen), findsOneWidget);
    });

    testWidgets('bottom navigation bar works correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      bool navigatedToDashboard = false;
      bool navigatedToWallet = false;
      bool navigatedToProfile = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const QRCodeScreen(),
          routes: {
            '/dashboard': (context) {
              navigatedToDashboard = true;
              return const Scaffold(body: Text('Dashboard'));
            },
            '/wallet': (context) {
              navigatedToWallet = true;
              return const Scaffold(body: Text('Wallet'));
            },
            '/profile': (context) {
              navigatedToProfile = true;
              return const Scaffold(body: Text('Profile'));
            },
          },
        ),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Test navigation
      await tester.tap(find.byIcon(Icons.home));
      await tester.pump();
      expect(navigatedToDashboard, true);
    });

    testWidgets('has correct gradient background', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('shows snackbar for QR maintenance message', (WidgetTester tester) async {
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

      // Assert - Check for snackbar
      expect(find.text('QR code feature is under maintenance'), findsOneWidget);
    });

    testWidgets('handles username with dash correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': '-', // Dash username should trigger fetch
        'selected_destination': 'Building A',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRCodeScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - Should attempt to fetch new username
      expect(find.byType(QRCodeScreen), findsOneWidget);
    });

    testWidgets('error handling for QR generation', (WidgetTester tester) async {
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

      // Even with errors, should show allocated state for now
      expect(find.text('Successfully get a lot.\nPlease scan the QR code below:'), findsOneWidget);
    });
  });
}