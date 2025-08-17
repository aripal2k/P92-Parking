import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userRegistration_screen.dart';
import 'package:autospot/user/userOTPVerification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('RegistrationScreen Widget Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays all registration form fields', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Assert
      expect(find.text('Account Registration'), findsOneWidget);
      expect(find.text('Please fill in your details to create an account.'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
      
      // Check all form fields
      expect(find.widgetWithText(TextField, 'Full Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Re-write Password'), findsOneWidget);
      
      // Check buttons
      expect(find.widgetWithText(ElevatedButton, 'Back'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
    });

    testWidgets('password validation indicators work correctly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Act - Type a weak password
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'weak');
      await tester.pump();

      // Assert - Check password requirements
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Contains uppercase'), findsOneWidget);
      expect(find.text('Contains lowercase'), findsOneWidget);
      expect(find.text('Contains number'), findsOneWidget);
      expect(find.text('Contains special char'), findsOneWidget);
      
      // Red X icons should be visible for failed requirements
      expect(find.byIcon(Icons.cancel), findsNWidgets(4)); // All except lowercase
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Only lowercase

      // Act - Type a strong password
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'StrongP@ss123');
      await tester.pump();

      // Assert - All requirements should be met
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('shows error when fields are empty', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Act - Tap register without filling any fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('shows error for invalid email', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Act - Fill all fields with invalid email
      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'invalidemail');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'testuser');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'StrongP@ss123');
      await tester.enterText(find.widgetWithText(TextField, 'Re-write Password'), 'StrongP@ss123');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text('Invalid email.'), findsOneWidget);
    });

    testWidgets('shows error when passwords do not match', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Act - Fill all fields with mismatched passwords
      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'testuser');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'StrongP@ss123');
      await tester.enterText(find.widgetWithText(TextField, 'Re-write Password'), 'DifferentPass123');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text("Passwords don't match."), findsOneWidget);
    });

    testWidgets('shows error when password does not meet requirements', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Act - Fill all fields with weak password
      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'testuser');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'weakpass');
      await tester.enterText(find.widgetWithText(TextField, 'Re-write Password'), 'weakpass');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      // Assert
      expect(find.text('Password does not meet all requirements.'), findsOneWidget);
    });

    testWidgets('navigates to OTP verification on successful validation', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const RegistrationScreen(),
          routes: {
            '/otp-verify': (context) => VerifyOtpScreen(
              userData: ModalRoute.of(context)!.settings.arguments as Map<String, String>,
            ),
          },
        ),
      );

      // Act - Fill all fields correctly
      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'testuser');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'StrongP@ss123');
      await tester.enterText(find.widgetWithText(TextField, 'Re-write Password'), 'StrongP@ss123');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();

      // Assert - Should navigate to OTP screen
      expect(find.byType(VerifyOtpScreen), findsOneWidget);
    });

    testWidgets('back button exists and has correct styling', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Assert - Verify back button exists with correct properties
      expect(find.widgetWithText(ElevatedButton, 'Back'), findsOneWidget);
      
      final backButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Back')
      );
      
      // Verify the button has onPressed callback
      expect(backButton.onPressed, isNotNull);
    });

    testWidgets('password fields are obscured', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Assert
      final passwordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Password')
      );
      final confirmPasswordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Re-write Password')
      );
      
      expect(passwordField.obscureText, isTrue);
      expect(confirmPasswordField.obscureText, isTrue);
    });

    testWidgets('text fields trim whitespace', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: const RegistrationScreen(),
          routes: {
            '/otp-verify': (context) => VerifyOtpScreen(
              userData: ModalRoute.of(context)!.settings.arguments as Map<String, String>,
            ),
          },
        ),
      );

      // Act - Fill fields with extra whitespace
      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), '  Test User  ');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), '  test@example.com  ');
      await tester.enterText(find.widgetWithText(TextField, 'Username'), '  testuser  ');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'StrongP@ss123');
      await tester.enterText(find.widgetWithText(TextField, 'Re-write Password'), 'StrongP@ss123');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pumpAndSettle();

      // Assert - Should navigate successfully (trimming worked)
      expect(find.byType(VerifyOtpScreen), findsOneWidget);
    });

    testWidgets('gradient background is rendered correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Container),
        ).first,
      );
      
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, [const Color(0xFFD4EECD), const Color(0xFFA3DB94)]);
    });

    testWidgets('app bar has transparent background', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);
    });
  });
}