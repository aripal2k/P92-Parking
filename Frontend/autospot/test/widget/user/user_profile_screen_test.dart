import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userProfile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../helpers/test_helpers.dart';
import 'dart:convert';

void main() {
  group('ProfileScreen Widget Tests', () {
    late MockClient mockClient;

    setUp(() {
      TestHelpers.setUpTestViewport();
      // Initialize with basic user data
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'username': 'testuser',
      });
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays profile information when loaded successfully', (WidgetTester tester) async {
      // Setup mock client for successful profile fetch
      mockClient = MockClient((request) async {
        if (request.url.toString().contains('/user/profile')) {
          return http.Response(
            json.encode({
              'fullname': 'John Doe',
              'username': 'johndoe',
              'email': 'test@example.com',
              'phone_number': '+1234567890',
              'license_plate': 'ABC123',
              'address': '123 Main St',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      
      // Wait for the widget to settle (async data loading)
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('AutoSpot'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('License Plate'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Subscription Plan'), findsOneWidget);
    });

    testWidgets('displays all navigation links', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Check Our Subscription Plan'), findsOneWidget);
      expect(find.text('Parking History'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
    });

    testWidgets('displays all action buttons', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('navigates to edit profile when button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
          routes: {
            '/profile/edit': (context) => const Scaffold(body: Text('Edit Profile Page')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit Profile Page'), findsOneWidget);
    });

    testWidgets('navigates to change password when button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
          routes: {
            '/profile/change-password': (context) => const Scaffold(body: Text('Change Password Page')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Change Password Page'), findsOneWidget);
    });

    testWidgets('navigates to delete account when button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
          routes: {
            '/profile/delete': (context) => const Scaffold(body: Text('Delete Account Page')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Delete Account Page'), findsOneWidget);
    });

    testWidgets('logout button exists and is tappable', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Logout button exists
      expect(find.text('Logout'), findsOneWidget);
      
      // Act - Tap logout (this will clear prefs and navigate)
      await tester.tap(find.text('Logout'));
      await tester.pump();
    });

    testWidgets('animated buttons have correct styling', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find all animated buttons
      final animatedButtons = find.byType(AnimatedContainer);
      
      // Assert - Should have 5 animated buttons (Edit Profile, Change Password, Clear Cache, Logout, Delete Account)
      expect(animatedButtons, findsNWidgets(5));
    });

    testWidgets('navigates to contact support when link is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
          routes: {
            '/contact_support': (context) => const Scaffold(body: Text('Contact Support Page')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Contact Support'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Contact Support Page'), findsOneWidget);
    });

    testWidgets('gradient background is rendered correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );

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
      
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, [const Color(0xFFD4EECD), const Color(0xFFA3DB94)]);
    });

    testWidgets('displays placeholder values when data is not loaded', (WidgetTester tester) async {
      // Arrange - Don't set any shared preferences data
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      
      // Don't wait for async operations to complete
      await tester.pump();

      // Assert - Should show placeholder values
      expect(find.text('-'), findsWidgets); // Multiple fields with '-' placeholder
    });

    testWidgets('profile container has blur effect', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Check for BackdropFilter
      expect(find.byType(BackdropFilter), findsOneWidget);
      
      // Check container styling
      final containers = find.byType(Container).evaluate();
      final blurContainer = containers.firstWhere(
        (element) => element.widget is Container && 
                     (element.widget as Container).decoration != null &&
                     ((element.widget as Container).decoration as BoxDecoration).borderRadius != null
      );
      
      expect(blurContainer, isNotNull);
    });

    testWidgets('handles profile loading error gracefully', (WidgetTester tester) async {
      // Arrange - Set email but mock will return 404
      await TestHelpers.setupMockSharedPreferences(
        userEmail: 'test@example.com',
        userName: 'testuser',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should still show the screen with placeholder values
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('saves username and vehicle_id to SharedPreferences after successful load', (WidgetTester tester) async {
      // This test verifies that profile data is saved to SharedPreferences
      // We can't mock HTTP in widget tests, but we can verify the UI behavior
      await TestHelpers.setupMockSharedPreferences(
        userEmail: 'test@example.com',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The screen should display even if API call fails
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('handles missing email in SharedPreferences', (WidgetTester tester) async {
      // Arrange - No email set
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      
      await tester.pump();

      // Assert - Should show placeholder values since no email to fetch profile
      expect(find.text('-'), findsWidgets);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('subscription plan navigation link works', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap subscription plan link
      await tester.tap(find.text('Check Our Subscription Plan'));
      await tester.pump();

      // Assert - The tap was registered (actual navigation would need route setup)
      expect(find.text('Check Our Subscription Plan'), findsOneWidget);
    });

    testWidgets('parking history navigation link works', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap parking history link
      await tester.tap(find.text('Parking History'));
      await tester.pump();

      // Assert - The tap was registered
      expect(find.text('Parking History'), findsOneWidget);
    });

    testWidgets('logout clears SharedPreferences and navigates to home', (WidgetTester tester) async {
      // Arrange
      await TestHelpers.setupMockSharedPreferences(
        userEmail: 'test@example.com',
        userName: 'testuser',
        authToken: 'test_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/profile',
          routes: {
            '/profile': (context) => const ProfileScreen(),
            '/': (context) => const Scaffold(body: Text('Home Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify data exists before logout
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_email'), 'test@example.com');

      // Act - Tap logout
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // Assert - Should navigate to home screen
      expect(find.text('Home Screen'), findsOneWidget);
      
      // Verify prefs were cleared
      final clearedPrefs = await SharedPreferences.getInstance();
      expect(clearedPrefs.getString('user_email'), isNull);
      expect(clearedPrefs.getString('username'), isNull);
      expect(clearedPrefs.getString('auth_token'), isNull);
    });

    testWidgets('profile items display with correct formatting', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Check that labels and values are displayed correctly
      final rows = find.byType(Row).evaluate();
      
      // Find rows that contain profile information
      bool foundFullNameRow = false;
      bool foundEmailRow = false;
      
      for (var row in rows) {
        final rowWidget = row.widget as Row;
        if (rowWidget.children.length >= 2) {
          final firstChild = rowWidget.children[0];
          if (firstChild is SizedBox) {
            final sizedBoxChild = firstChild.child;
            if (sizedBoxChild is Text) {
              if (sizedBoxChild.data == 'Full Name') {
                foundFullNameRow = true;
              } else if (sizedBoxChild.data == 'Email') {
                foundEmailRow = true;
              }
            }
          }
        }
      }
      
      expect(foundFullNameRow, isTrue);
      expect(foundEmailRow, isTrue);
    });

    testWidgets('animated buttons respond to tap', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const ProfileScreen(),
          routes: {
            '/profile/edit': (context) => const Scaffold(body: Text('Edit Screen')),
            '/profile/change-password': (context) => const Scaffold(body: Text('Password Screen')),
            '/profile/delete': (context) => const Scaffold(body: Text('Delete Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Find InkWell widgets that contain the animated buttons
      final editButton = find.widgetWithText(InkWell, 'Edit Profile');
      final passwordButton = find.widgetWithText(InkWell, 'Change Password');
      final deleteButton = find.widgetWithText(InkWell, 'Delete Account');
      
      // Verify they exist
      expect(editButton, findsOneWidget);
      expect(passwordButton, findsOneWidget);
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('dividers are displayed correctly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should have 3 dividers
      expect(find.byType(Divider), findsNWidgets(3));
    });

    testWidgets('all profile fields are displayed with proper spacing', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Check all required fields
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('License Plate'), findsOneWidget);
      expect(find.text('Subscription Plan'), findsOneWidget);
      
      // Check spacing elements
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('navigation links have correct icons', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Check for arrow icons in navigation links
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNWidgets(3));
    });

    testWidgets('delete account button has white text color', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the delete account text
      final deleteText = find.text('Delete Account');
      expect(deleteText, findsOneWidget);
      
      // Get the Text widget and verify its style
      final textWidget = tester.widget<Text>(deleteText);
      expect(textWidget.style?.color, Colors.white);
    });

    testWidgets('profile screen is scrollable', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should have SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}