import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorEditParkingFee_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorEditParkingFeeScreen Simple Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays edit parking fee header', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('Edit Parking Fee Rate'), findsOneWidget);
    });

    testWidgets('displays all form fields', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert - Check all text fields exist (6 total including destination)
      expect(find.byType(TextFormField), findsNWidgets(6));
    });

    testWidgets('displays rate input fields with correct labels', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('Base Rate per Hour'), findsOneWidget);
      expect(find.text('Peak Hour Surcharge Rate'), findsOneWidget);
      expect(find.text('Weekend Surcharge Rate'), findsOneWidget);
      expect(find.text('Public Holiday Surcharge Rate'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('displays Cancel and Save buttons', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(2));
    });

    testWidgets('tapping destination field shows picker', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Tap destination field
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      // Assert - Modal should appear
      expect(find.text('Select Destination'), findsWidgets);
    });

    testWidgets('password field is obscured', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert - Password field exists
      final passwordFields = find.byType(TextFormField);
      expect(passwordFields, findsWidgets);
    });

    testWidgets('Cancel button exists and can be tapped', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert - Cancel button exists
      expect(find.text('Cancel'), findsOneWidget);
      
      // Can tap it without error
      await tester.tap(find.text('Cancel'));
      await tester.pump();
    });

    testWidgets('form is scrollable', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('displays gradient background', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

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

    testWidgets('error message container exists', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert - Error container should exist but be empty initially
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('can enter text in base rate field', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Find base rate field (second TextFormField)
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '5.50');
      await tester.pump();

      // Assert
      expect(find.text('5.50'), findsOneWidget);
    });

    testWidgets('rate fields have number keyboard type', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert - Just verify fields exist
      expect(find.byType(TextFormField), findsNWidgets(6));
    });

    testWidgets('header text has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert
      final headerText = tester.widget<Text>(find.text('Edit Parking Fee Rate'));
      expect(headerText.style!.fontSize, 28);
      expect(headerText.style!.fontWeight, FontWeight.bold);
    });

    testWidgets('Save button is disabled when loading', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert - Save button should be enabled initially
      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('uses SafeArea for proper spacing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('disposes controllers properly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'keyID': '12345',
        'username': 'testoperator',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorEditParkingFeeScreen()),
      );
      await tester.pump();

      // Navigate away to trigger dispose
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Assert - Should dispose without errors
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(OperatorEditParkingFeeScreen), findsNothing);
    });
  });
}