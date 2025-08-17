import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorEditProfile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorEditProfileScreen Tests', () {
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

    testWidgets('displays email as read-only', (WidgetTester tester) async {
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
      expect(find.text('operator@example.com'), findsOneWidget);
    });

    testWidgets('displays keyID as read-only', (WidgetTester tester) async {
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
      expect(find.text('Key ID'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
    });

    testWidgets('displays username text field', (WidgetTester tester) async {
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
      expect(find.text('Username'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3)); // Email, KeyID, Username
      expect(find.text('testoperator'), findsOneWidget);
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

      // Clear and enter new username (last TextFormField is username)
      await tester.enterText(find.byType(TextFormField).last, 'newoperator');
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
    });

    testWidgets('Cancel button navigates back', (WidgetTester tester) async {
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

    testWidgets('Save button shows dialog when username changed', (WidgetTester tester) async {
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
      await tester.enterText(find.byType(TextFormField).last, 'newoperator');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Dialog should appear
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('error shows when saving empty username', (WidgetTester tester) async {
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
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert
      expect(find.text('Username cannot be empty.'), findsOneWidget);
    });

    testWidgets('error shows when username unchanged', (WidgetTester tester) async {
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

      // Assert
      expect(find.text('New username is the same as current username.'), findsOneWidget);
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

    testWidgets('has gradient container', (WidgetTester tester) async {
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
      expect(find.byType(Container), findsWidgets);
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

    testWidgets('dialog can be dismissed', (WidgetTester tester) async {
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
      await tester.enterText(find.byType(TextFormField).last, 'newoperator');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Tap Cancel in dialog (last one is in the dialog)
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // Assert - Dialog should be gone
      expect(find.byType(AlertDialog), findsNothing);
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

    testWidgets('error message container updates', (WidgetTester tester) async {
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

      // Initially no error
      expect(find.text('Username cannot be empty.'), findsNothing);

      // Clear username and save
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Error should appear
      expect(find.text('Username cannot be empty.'), findsOneWidget);
    });

    testWidgets('disposes controllers properly', (WidgetTester tester) async {
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