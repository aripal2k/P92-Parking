import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorProfile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorProfileScreen Simple Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays AutoSpot header', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('AutoSpot'), findsOneWidget);
    });

    testWidgets('displays profile title', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('Profile'), findsWidgets); // Can be multiple
    });

    testWidgets('displays user information labels', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Key ID'), findsOneWidget);
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
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('operator@example.com'), findsOneWidget);
      expect(find.text('testoperator'), findsOneWidget);
      expect(find.text('12345'), findsOneWidget);
    });

    testWidgets('displays action buttons', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert - Check for action button labels
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Edit Parking Fee Rate'), findsOneWidget);
      expect(find.text('Upload Map'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
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
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
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

    testWidgets('has bottom navigation bar', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('bottom navigation has correct selection', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final bottomNav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bottomNav.currentIndex, 3); // Profile is selected (index 3)
    });

    testWidgets('profile content is scrollable', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('handles missing user data gracefully', (WidgetTester tester) async {
      // Arrange - No data in SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert - Should display defaults
      expect(find.text('-'), findsNWidgets(3)); // Default values
    });

    testWidgets('uses SafeArea for proper spacing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('profile section has blur effect', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('has dividers for visual separation', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(Divider), findsWidgets);
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
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('has InkWell buttons for interactions', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(InkWell), findsNWidgets(5)); // 5 action buttons
    });

    testWidgets('can tap Edit Profile button', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Test tapping Edit Profile
      await tester.tap(find.text('Edit Profile'));
      await tester.pump();

      // Assert - The tap should not cause errors
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('has animated containers for buttons', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(AnimatedContainer), findsNWidgets(5)); // 5 animated buttons
    });

    testWidgets('scaffold extends body for navigation bar', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@example.com',
        'username': 'testoperator',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
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
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Navigate away
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Assert - Should dispose without errors
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(OperatorProfileScreen), findsNothing);
    });
  });
}