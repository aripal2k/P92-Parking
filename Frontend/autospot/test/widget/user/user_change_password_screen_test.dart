import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/user/userChangePassword_screen.dart';

void main() {
  late SharedPreferences mockPrefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
  });

  void setLargeScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.resetDevicePixelRatio();
  });

  group('ChangePasswordScreen Tests', () {
    testWidgets('displays all form fields', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check all fields are present
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      
      // Check email is displayed
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows password requirements', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check all requirements are shown
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Contains uppercase'), findsOneWidget);
      expect(find.text('Contains lowercase'), findsOneWidget);
      expect(find.text('Contains number'), findsOneWidget);
      expect(find.text('Contains special character'), findsOneWidget);
    });

    testWidgets('validates password requirements dynamically', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter a weak password
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'abc');
      await tester.pump();

      // Only lowercase requirement should be met
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Only lowercase check
      expect(find.byIcon(Icons.cancel), findsNWidgets(4)); // Other 4 requirements not met

      // Enter a stronger password
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'Abc123!@#');
      await tester.pump();

      // All requirements should be met
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('shows password visibility toggles', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should have 3 visibility toggles
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(3));
      
      // Tap first toggle
      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();
      
      // Should now show visibility icon for the first field
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
    });

    testWidgets('shows error when passwords do not match', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter different passwords
      await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'OldPass123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'NewPass123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'DifferentPass123!');
      
      // Tap Save button
      await tester.tap(find.text('Save'));
      await tester.pump();
      
      // Should show error message
      expect(find.text('New passwords do not match.'), findsOneWidget);
    });

    testWidgets('shows error when fields are empty', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Save button without entering anything
      await tester.tap(find.text('Save'));
      await tester.pump();
      
      // Should show error message
      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);
      expect(appBar.centerTitle, true);
    });

    testWidgets('has gradient background', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('Cancel button navigates back', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      bool navigatedBack = false;

      await tester.pumpWidget(
        MaterialApp(
          home: const ChangePasswordScreen(),
          routes: {
            '/profile': (context) {
              navigatedBack = true;
              return const Scaffold(body: Text('Profile'));
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      // Should navigate back
      expect(navigatedBack || find.text('Cancel').evaluate().isEmpty, true);
    });

    testWidgets('buttons have correct styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check Cancel button
      final cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Cancel'),
      );
      expect(cancelButton.style!.backgroundColor!.resolve({}), Colors.grey[300]);
      
      // Check Save button
      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );
      expect(saveButton.style!.backgroundColor!.resolve({}), const Color(0xFFA3DB94));
    });

    testWidgets('email field is disabled', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the email field
      final emailField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Email'),
      );
      
      expect(emailField.enabled, false);
    });

    testWidgets('shows dash when no email is found', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      // No email set in preferences

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show dash for email
      expect(find.text('-'), findsOneWidget);
    });

    testWidgets('back button is present', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows error for weak password', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter a weak password
      await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'OldPass123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'weak');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'weak');
      
      // Tap Save button
      await tester.tap(find.text('Save'));
      await tester.pump();
      
      // Should show error message
      expect(find.text('Password does not meet all requirements.'), findsOneWidget);
    });
  });
}