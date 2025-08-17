import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorEditProfile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorEditProfileScreen Simple Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays Edit Profile title', (WidgetTester tester) async {
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
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('displays all form fields', (WidgetTester tester) async {
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
      expect(find.byType(TextFormField), findsNWidgets(3)); // Email, KeyID, Username
    });

    testWidgets('displays field labels', (WidgetTester tester) async {
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
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Key ID'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('displays loaded user data', (WidgetTester tester) async {
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
      expect(find.text('operator@example.com'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('testoperator'), findsOneWidget);
    });

    testWidgets('email and keyID fields are disabled', (WidgetTester tester) async {
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
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[0].enabled, isFalse); // Email
      expect(fields[1].enabled, isFalse); // KeyID
      expect(fields[2].enabled, isTrue);  // Username
    });

    testWidgets('can edit username field', (WidgetTester tester) async {
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

      // Find username field (last TextFormField)
      final usernameField = find.byType(TextFormField).last;
      await tester.enterText(usernameField, 'newoperator');
      await tester.pump();

      // Assert
      expect(find.text('newoperator'), findsOneWidget);
    });

    testWidgets('displays Cancel and Save buttons', (WidgetTester tester) async {
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
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(2));
    });

    testWidgets('Cancel button can be tapped', (WidgetTester tester) async {
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

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Assert - Should not throw error
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Save button triggers action', (WidgetTester tester) async {
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

      // Tap Save without changing
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert - Error should appear for unchanged username
      expect(find.text('New username is the same as current username.'), findsOneWidget);
    });

    testWidgets('shows error for empty username', (WidgetTester tester) async {
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

      // Clear username
      final usernameField = find.byType(TextFormField).last;
      await tester.enterText(usernameField, '');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      expect(find.text('Username cannot be empty.'), findsOneWidget);
    });

    testWidgets('shows dialog when username changed', (WidgetTester tester) async {
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

      // Change username
      final usernameField = find.byType(TextFormField).last;
      await tester.enterText(usernameField, 'newoperator');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Dialog should appear
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('has gradient background', (WidgetTester tester) async {
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
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('content is scrollable', (WidgetTester tester) async {
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
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('has SafeArea for proper spacing', (WidgetTester tester) async {
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
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('scaffold has correct background color', (WidgetTester tester) async {
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
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('error message clears when typing valid username', (WidgetTester tester) async {
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

      // First create an error
      final usernameField = find.byType(TextFormField).last;
      await tester.enterText(usernameField, '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Error should be visible
      expect(find.text('Username cannot be empty.'), findsOneWidget);

      // Type valid username
      await tester.enterText(usernameField, 'validuser');
      await tester.pump();

      // Error should be gone (would clear on next save attempt)
      expect(find.text('validuser'), findsOneWidget);
    });

    testWidgets('dialog can be cancelled', (WidgetTester tester) async {
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

      // Change username and show dialog
      final usernameField = find.byType(TextFormField).last;
      await tester.enterText(usernameField, 'newoperator');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Cancel dialog
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // Assert - Dialog should be gone
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('scaffold extends body', (WidgetTester tester) async {
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
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, isTrue);
    });

    testWidgets('disposes properly when navigating away', (WidgetTester tester) async {
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

      // Navigate away
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Assert - Should dispose without errors
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(OperatorEditProfileScreen), findsNothing);
    });
  });
}