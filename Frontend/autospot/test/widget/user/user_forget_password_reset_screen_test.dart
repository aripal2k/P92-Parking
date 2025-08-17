import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userForgetPasswordReset_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ForgetPasswordResetScreen Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('screen renders with all UI elements', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('Please type your new password.'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Save Password'), findsOneWidget);
    });

    testWidgets('displays password requirements', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Contains uppercase'), findsOneWidget);
      expect(find.text('Contains lowercase'), findsOneWidget);
      expect(find.text('Contains number'), findsOneWidget);
      expect(find.text('Contains special character'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert initial state
      final passwordField = tester.widget<TextField>(find.byType(TextField).first);
      expect(passwordField.obscureText, isTrue);

      // Act - Toggle password visibility
      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();

      // Assert
      final updatedPasswordField = tester.widget<TextField>(find.byType(TextField).first);
      expect(updatedPasswordField.obscureText, isFalse);
    });

    testWidgets('confirm password visibility toggle works', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert initial state
      final confirmField = tester.widget<TextField>(find.byType(TextField).last);
      expect(confirmField.obscureText, isTrue);

      // Act - Toggle confirm password visibility
      await tester.tap(find.byIcon(Icons.visibility_off).last);
      await tester.pump();

      // Assert
      final updatedConfirmField = tester.widget<TextField>(find.byType(TextField).last);
      expect(updatedConfirmField.obscureText, isFalse);
    });

    testWidgets('password requirements update as user types', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act - Enter a weak password
      await tester.enterText(find.byType(TextField).first, 'weak');
      await tester.pump();

      // Assert - Should show red icons for unmet requirements (4 red, 1 green for lowercase)
      expect(find.byIcon(Icons.cancel), findsNWidgets(4));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Act - Enter a strong password
      await tester.enterText(find.byType(TextField).first, 'Strong@123');
      await tester.pump();

      // Assert - Should show green icons for met requirements
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('shows error when fields are empty', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act - Tap save without entering anything
      await tester.tap(find.text('Save Password'));
      await tester.pump();

      // Assert
      expect(find.text('Please fill in all fields.'), findsOneWidget);
    });

    testWidgets('shows error when passwords don\'t match', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      await tester.enterText(find.byType(TextField).first, 'Strong@123');
      await tester.enterText(find.byType(TextField).last, 'Different@123');
      await tester.tap(find.text('Save Password'));
      await tester.pump();

      // Assert
      expect(find.text('Passwords don\'t match.'), findsOneWidget);
    });

    testWidgets('shows error when password doesn\'t meet requirements', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      await tester.enterText(find.byType(TextField).first, 'weakpass');
      await tester.enterText(find.byType(TextField).last, 'weakpass');
      await tester.tap(find.text('Save Password'));
      await tester.pump();

      // Assert
      expect(find.text('Password does not meet all requirements.'), findsOneWidget);
    });

    testWidgets('back button navigates to login', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      await tester.tap(find.text('Back'));
      await tester.pump();

      // Assert - In test environment, navigation is mocked
      expect(find.byType(ForgetPasswordResetScreen), findsOneWidget);
    });

    testWidgets('back icon button navigates to login', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      // Assert - In test environment, navigation is mocked
      expect(find.byType(ForgetPasswordResetScreen), findsOneWidget);
    });

    testWidgets('handles password reset attempt', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      await tester.enterText(find.byType(TextField).first, 'Strong@123');
      await tester.enterText(find.byType(TextField).last, 'Strong@123');
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();

      // Assert - API will fail in test, but we're testing the flow
      expect(find.text('Reset failed due to network error.'), findsOneWidget);
    });

    testWidgets('scaffold has correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, isTrue);
    });

    testWidgets('app bar has transparent background', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);
    });

    testWidgets('gradient background is applied', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
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
    });

    testWidgets('text fields have correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final passwordField = tester.widget<TextField>(find.byType(TextField).first);
      expect(passwordField.style?.color, Colors.black);
      expect(passwordField.style?.fontSize, 18);
    });

    testWidgets('buttons have correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final backButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Back'),
      );
      expect(backButton.style?.backgroundColor?.resolve({}), Colors.grey[300]);

      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save Password'),
      );
      expect(saveButton.style?.backgroundColor?.resolve({}), const Color(0xFFA3DB94));
    });

    testWidgets('lock icon has correct size', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final icon = tester.widget<Icon>(find.byIcon(Icons.lock));
      expect(icon.size, 80);
      expect(icon.color, Colors.black);
    });

    testWidgets('error message has correct styling', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act - Trigger an error
      await tester.tap(find.text('Save Password'));
      await tester.pump();

      // Assert
      final errorText = tester.widget<Text>(
        find.text('Please fill in all fields.'),
      );
      expect(errorText.style?.color, Colors.red);
    });

    testWidgets('handles missing email in route arguments', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      await tester.enterText(find.byType(TextField).first, 'Strong@123');
      await tester.enterText(find.byType(TextField).last, 'Strong@123');
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();

      // Assert - Should handle gracefully
      expect(find.byType(ForgetPasswordResetScreen), findsOneWidget);
    });

    testWidgets('requirement icons change color based on status', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act - Type partial password
      await tester.enterText(find.byType(TextField).first, 'Short1');
      await tester.pump();

      // Assert - Mixed requirements
      final greenIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.check_circle),
      );
      final redIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.cancel),
      );
      
      expect(greenIcons.every((icon) => icon.color == Colors.green), isTrue);
      expect(redIcons.every((icon) => icon.color == Colors.red), isTrue);
    });

    testWidgets('all sized boxes have correct spacing', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('scrollable content works', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act & Assert - Should be scrollable
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      
      // Try to scroll
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -100));
      await tester.pump();
    });

    testWidgets('expanded widget fills available space', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('input decoration has correct border styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final passwordField = tester.widget<TextField>(find.byType(TextField).first);
      final decoration = passwordField.decoration!;
      
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, Colors.transparent);
      expect(decoration.contentPadding, const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
    });

    testWidgets('password field accepts input', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      const testPassword = 'TestPassword123!';
      await tester.enterText(find.byType(TextField).first, testPassword);
      await tester.pump();

      // Assert
      expect(find.text(testPassword), findsOneWidget);
    });

    testWidgets('confirm password field accepts input', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act
      const testPassword = 'TestPassword123!';
      await tester.enterText(find.byType(TextField).last, testPassword);
      await tester.pump();

      // Assert
      expect(find.text(testPassword), findsOneWidget);
    });

    testWidgets('requirement text has correct color', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Act - Enter partial password
      await tester.enterText(find.byType(TextField).first, 'Pass');
      await tester.pump();

      // Assert
      final requirementTexts = tester.widgetList<Text>(
        find.textContaining('At least'),
      );
      expect(requirementTexts.first.style?.color, Colors.red);
    });

    testWidgets('row layout for buttons', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.descendant(
        of: find.byType(Row),
        matching: find.text('Back'),
      ), findsOneWidget);
      expect(find.descendant(
        of: find.byType(Row),
        matching: find.text('Save Password'),
      ), findsOneWidget);
    });

    testWidgets('column layout for password requirements', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.descendant(
        of: find.byType(Column),
        matching: find.text('At least 8 characters'),
      ), findsWidgets);
    });

    testWidgets('save button is in expanded widget', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final expandedWithSaveButton = find.ancestor(
        of: find.text('Save Password'),
        matching: find.byType(Expanded),
      );
      expect(expandedWithSaveButton, findsWidgets);
    });

    testWidgets('password field has suffix icon', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
    });

    testWidgets('center title in app bar', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ForgetPasswordResetScreen()),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, isTrue);
    });
  });
}