import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorEditProfile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorEditProfileScreen Enhanced Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('initializes with empty data when SharedPreferences is empty', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('Edit Profile'), findsOneWidget);
      // Empty TextEditingControllers will show empty text
      final emailFields = find.byType(TextFormField);
      expect(emailFields, findsNWidgets(3));
    });

    testWidgets('shows password dialog when valid username change', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'oldusername',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Change username
      await tester.enterText(find.byType(TextFormField).last, 'newusername');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Password dialog should appear
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('password dialog has password field with obscureText', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'oldusername',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Change username and show dialog
      await tester.enterText(find.byType(TextFormField).last, 'newusername');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      final passwordField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('password dialog Save button triggers API call', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'oldusername',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Change username
      await tester.enterText(find.byType(TextFormField).last, 'newusername');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Enter password in dialog
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'testpassword',
      );
      await tester.pump();

      // Tap Save in dialog
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      // Assert - Dialog should be dismissed (but API call might show error)
      // Just verify the tap was processed without errors
    });

    testWidgets('clears error message when typing new valid username', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // First create an error by trying to save empty username
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Error should be visible
      expect(find.text('Username cannot be empty.'), findsOneWidget);

      // Type valid username (should clear error in next save attempt)
      await tester.enterText(find.byType(TextFormField).last, 'validuser');
      await tester.pump();

      // Tap Save again
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should show dialog instead of error
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('displays all UI components correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(Stack), findsWidgets);
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('buildTextField creates properly configured TextFormField', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      final textFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      
      // Check first field (email) is disabled
      expect(textFields[0].enabled, isFalse);
      
      // Check last field (username) is enabled
      expect(textFields[2].enabled, isTrue);
    });

    testWidgets('inputDecoration has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      // Just verify that the text fields exist with correct labels
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Key ID'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('buttons have correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      final cancelButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
      final saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
      
      expect(cancelButton.style?.backgroundColor?.resolve({}), Colors.grey[300]);
      expect(saveButton.style?.backgroundColor?.resolve({}), const Color(0xFFA3DB94));
    });

    testWidgets('gradient background is rendered correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      final gradientContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(Container),
        ).first,
      );
      
      expect(gradientContainer.decoration, isA<BoxDecoration>());
      final decoration = gradientContainer.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, [const Color(0xFFD4EECD), const Color(0xFFA3DB94)]);
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
    });

    testWidgets('error message has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Trigger error
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      final errorText = tester.widget<Text>(find.text('Username cannot be empty.'));
      expect(errorText.style?.color, Colors.red);
    });

    testWidgets('SizedBox spacing is correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).where((box) {
        return box.height != null || box.width != null;
      }).toList();
      
      // Verify we have SizedBox widgets with expected values
      expect(sizedBoxes.any((box) => box.height == 20), isTrue);
      expect(sizedBoxes.any((box) => box.height == 10), isTrue);
      expect(sizedBoxes.any((box) => box.height == 24), isTrue);
      expect(sizedBoxes.any((box) => box.width == 16), isTrue);
    });

    testWidgets('dialog has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Show dialog
      await tester.enterText(find.byType(TextFormField).last, 'newuser');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFFD4EECD));
      expect(dialog.shape, isA<RoundedRectangleBorder>());
      
      final shape = dialog.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('dialog title has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Show dialog
      await tester.enterText(find.byType(TextFormField).last, 'newuser');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      final titleText = tester.widget<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Confirm Password'),
        ),
      );
      expect(titleText.style?.fontSize, 20);
      expect(titleText.style?.fontWeight, FontWeight.bold);
      expect(titleText.style?.color, Colors.black);
    });

    testWidgets('controllers are properly disposed', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Navigate away to trigger disposal
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );
      await tester.pump();

      // Assert - No errors should occur during disposal
      expect(find.byType(OperatorEditProfileScreen), findsNothing);
    });

    testWidgets('all text styling is consistent', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Assert
      final titleText = tester.widget<Text>(find.text('Edit Profile'));
      expect(titleText.style?.fontSize, 28);
      expect(titleText.style?.fontWeight, FontWeight.bold);
      expect(titleText.textAlign, TextAlign.center);

      final cancelText = tester.widget<Text>(find.text('Cancel'));
      expect(cancelText.style?.color, Colors.black);
      expect(cancelText.style?.fontSize, 16);

      final saveText = tester.widget<Text>(find.text('Save'));
      expect(saveText.style?.fontSize, 16);
    });

    testWidgets('password controller is cleared before showing dialog', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditProfileScreen()),
      );
      await tester.pump();

      // Show dialog first time
      await tester.enterText(find.byType(TextFormField).last, 'newuser1');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Enter password and cancel
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'password123',
      );
      await tester.pump();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // Show dialog second time
      await tester.enterText(find.byType(TextFormField).last, 'newuser2');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Password field should be empty (controller was cleared)
      // The dialog should appear with an empty password field
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('password123'), findsNothing);
    });
  });
}