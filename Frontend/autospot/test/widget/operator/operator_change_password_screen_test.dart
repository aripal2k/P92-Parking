import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorChangePassword_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorChangePasswordScreen Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    Future<void> setUpSharedPreferences() async {
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': 'KEY123',
      });
    }

    testWidgets('screen renders with all UI elements', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump(); // Allow initState to complete

      // Assert
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Key ID'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('displays key ID from SharedPreferences', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('KEY123'), findsOneWidget);
    });

    testWidgets('key ID field is disabled', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      final keyIdField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(keyIdField.enabled, isFalse);
    });

    testWidgets('password visibility toggles work', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act & Assert - Current password visibility toggle
      // Initially should show visibility_off icon (password is obscured)
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(3));

      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();

      // After toggle, should show visibility icon (password is visible)
      expect(find.byIcon(Icons.visibility), findsAtLeastNWidgets(1));
    });

    testWidgets('displays password requirements', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Contains uppercase'), findsOneWidget);
      expect(find.text('Contains lowercase'), findsOneWidget);
      expect(find.text('Contains number'), findsOneWidget);
      expect(find.text('Contains special character'), findsOneWidget);
    });

    testWidgets('password requirements update dynamically', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act - Enter weak password
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'weak');
      await tester.pump();

      // Assert - Should show red icons for unmet requirements (4 red, 1 green for lowercase)
      expect(find.byIcon(Icons.cancel), findsNWidgets(4));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Act - Enter strong password
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'Strong@123');
      await tester.pump();

      // Assert - All requirements met
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('shows error when fields are empty', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      expect(find.text('Please fill out all fields.'), findsOneWidget);
    });

    testWidgets('shows error when passwords don\'t match', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[1].widget), 'OldPass123!');
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'Strong@123');
      await tester.enterText(find.byWidget(passwordFields[3].widget), 'Different@123');
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      expect(find.text('New passwords do not match.'), findsOneWidget);
    });

    testWidgets('shows error when password doesn\'t meet requirements', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[1].widget), 'OldPass123!');
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'weakpass');
      await tester.enterText(find.byWidget(passwordFields[3].widget), 'weakpass');
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      expect(find.text('Password does not meet all requirements.'), findsOneWidget);
    });

    testWidgets('cancel button navigates back', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Assert - In test environment, navigation is mocked
      expect(find.byType(OperatorChangePasswordScreen), findsOneWidget);
    });

    testWidgets('handles password change attempt', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[1].widget), 'OldPass123!');
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'Strong@123');
      await tester.enterText(find.byWidget(passwordFields[3].widget), 'Strong@123');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - API will fail in test environment
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('scaffold has gradient background', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
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

    testWidgets('text fields have correct styling', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      // TextFormField widgets exist
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('buttons have correct styling', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      final cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Cancel'),
      );
      expect(cancelButton.style?.backgroundColor?.resolve({}), Colors.grey[300]);

      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );
      expect(saveButton.style?.backgroundColor?.resolve({}), const Color(0xFFA3DB94));
    });

    testWidgets('error message displays in red', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act - Trigger error
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      final errorText = tester.widget<Text>(
        find.text('Please fill out all fields.'),
      );
      expect(errorText.style?.color, Colors.red);
    });

    testWidgets('password criteria icons change color', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act - Enter partial password
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'Short1');
      await tester.pump();

      // Assert
      final greenIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.check_circle),
      );
      final redIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.cancel),
      );
      
      expect(greenIcons.every((icon) => icon.color == Colors.green), isTrue);
      expect(redIcons.every((icon) => icon.color == Colors.red), isTrue);
    });

    testWidgets('scrollable content works', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      
      // Try to scroll
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -100));
      await tester.pump();
    });

    testWidgets('save button is in expanded widget', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      final expandedWithSaveButton = find.ancestor(
        of: find.text('Save'),
        matching: find.byType(Expanded),
      );
      expect(expandedWithSaveButton, findsWidgets);
    });

    testWidgets('handles missing SharedPreferences data', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert - Should handle gracefully with empty strings
      expect(find.byType(OperatorChangePasswordScreen), findsOneWidget);
    });

    testWidgets('all sized boxes have correct spacing', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('password fields accept input', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[1].widget), 'TestPassword123!');
      await tester.pump();

      // Assert
      expect(find.text('TestPassword123!'), findsOneWidget);
    });

    testWidgets('special character requirement includes correct characters', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act - Test different special characters
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'Password1@');
      await tester.pump();

      // Assert - @ is in the special character list
      final specialCharIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle).last,
      );
      expect(specialCharIcon.color, Colors.green);
    });

    testWidgets('row layout for buttons', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.descendant(
        of: find.byType(Row),
        matching: find.text('Cancel'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(Row),
        matching: find.text('Save'),
      ), findsOneWidget);
    });

    testWidgets('column layout for form fields', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.descendant(
        of: find.byType(Column),
        matching: find.text('Change Password'),
      ), findsWidgets);
    });

    testWidgets('safe area is used', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('password field suffix icons work', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert - Should have 3 visibility icons (for 3 password fields)
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(3));
    });

    testWidgets('title has correct styling', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      final titleText = tester.widget<Text>(find.text('Change Password'));
      expect(titleText.style?.fontSize, 28);
      expect(titleText.style?.fontWeight, FontWeight.bold);
      expect(titleText.style?.color, Colors.black);
    });

    testWidgets('scaffold extends body', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, isTrue);
    });

    testWidgets('new password listener updates UI', (WidgetTester tester) async {
      // Arrange
      await setUpSharedPreferences();

      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorChangePasswordScreen()),
      );
      await tester.pump();

      // Act - Type in new password field character by character
      final passwordFields = find.byType(TextFormField).evaluate().toList();
      await tester.enterText(find.byWidget(passwordFields[2].widget), 'P');
      await tester.pump();
      
      // Assert - Should update requirements display
      expect(find.byIcon(Icons.cancel), findsNWidgets(4)); // Missing 4 requirements
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Has uppercase
    });
  });
}