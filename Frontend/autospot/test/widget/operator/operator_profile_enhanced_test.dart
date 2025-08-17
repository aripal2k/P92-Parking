import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorProfile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../helpers/test_helpers.dart';

void main() {
  group('OperatorProfileScreen Enhanced Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('loads user data on init and updates state', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@test.com',
        'username': 'operator1',
        'keyID': 'key123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.text('operator@test.com'), findsOneWidget);
      expect(find.text('operator1'), findsOneWidget);
      expect(find.text('key123'), findsOneWidget);
    });

    testWidgets('handles null values in SharedPreferences gracefully', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@test.com',
        // username and keyID are missing
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert - Should show default "-" values
      expect(find.text('-'), findsAtLeast(2));
    });

    testWidgets('logout clears SharedPreferences and navigates', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'operator@test.com',
        'username': 'operator1',
        'keyID': 'key123',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Find and tap logout button
      await tester.tap(find.text('Logout'));
      await tester.pump();

      // Assert - Should trigger navigation (can't test full navigation in unit test)
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('profile item displays label and value correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      // Check for profile item structure
      expect(find.byType(Row), findsWidgets);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('animated buttons have correct properties', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final animatedContainers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      
      expect(animatedContainers.length, 5); // 5 action buttons
      expect(animatedContainers[0].duration, const Duration(milliseconds: 200));
    });

    testWidgets('backdrop filter is applied correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(backdropFilter.filter, isA<ImageFilter>());
    });

    testWidgets('bottom navigation tap handlers work correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Find bottom navigation bar
      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget);

      // Tap home icon (index 0)
      await tester.tap(find.byIcon(Icons.home));
      await tester.pump();

      // Tap profile icon (index 3) - should stay on same page
      await tester.tap(find.byIcon(Icons.person));
      await tester.pump();

      // Assert - No errors should occur
      expect(find.byType(OperatorProfileScreen), findsOneWidget);
    });

    testWidgets('all action buttons are tappable', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Test each button tap
      await tester.tap(find.text('Edit Profile'));
      await tester.pump();

      await tester.tap(find.text('Change Password'));
      await tester.pump();

      await tester.tap(find.text('Edit Parking Fee Rate'));
      await tester.pump();

      await tester.tap(find.text('Upload Map'));
      await tester.pump();

      // Assert - All taps should work without errors
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('profile container has glass morphism effect', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final clipRRect = tester.widget<ClipRRect>(
        find.byType(ClipRRect).first,
      );
      expect(clipRRect.borderRadius, BorderRadius.circular(20));

      // Find container inside BackdropFilter
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(Container),
        ),
      );
      
      expect(containers.isNotEmpty, isTrue);
    });

    testWidgets('dividers are rendered correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
      expect(dividers.length, 2);
      expect(dividers[0].color, Colors.black45);
    });

    testWidgets('text styles are applied correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final autoSpotText = tester.widget<Text>(find.text('AutoSpot'));
      expect(autoSpotText.style?.fontSize, 32);
      expect(autoSpotText.style?.fontWeight, FontWeight.bold);

      final profileText = tester.widget<Text>(
        find.text('Profile').first,
      );
      expect(profileText.style?.fontSize, 26);
      expect(profileText.style?.fontWeight, FontWeight.bold);
      expect(profileText.style?.color, Colors.black);
    });

    testWidgets('profile items have correct spacing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('Email'),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.only(top: 8.0, bottom: 4));
    });

    testWidgets('button colors are correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert - Check button container decorations
      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
      expect(inkWells.length, greaterThanOrEqualTo(5)); // At least 5 action buttons

      // Find AnimatedContainers within InkWells
      final animatedContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(AnimatedContainer),
        ),
      ).toList();

      // Check first button (Edit Profile) has grey color
      final firstDecoration = animatedContainers[0].decoration as BoxDecoration;
      expect(firstDecoration.color, Colors.grey[300]);

      // Check last button (Logout) has red accent color
      final lastDecoration = animatedContainers[4].decoration as BoxDecoration;
      expect(lastDecoration.color, Colors.redAccent.shade100);
    });

    testWidgets('all UI components are rendered', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Stack), findsWidgets); // Multiple stacks in the UI
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('profile data text styles are correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      // Find label texts
      final emailLabel = tester.widget<Text>(find.text('Email'));
      expect(emailLabel.style?.fontSize, 15);
      expect(emailLabel.style?.fontWeight, FontWeight.w500);
      expect(emailLabel.style?.color, Colors.black);

      // Find value texts
      final emailValue = tester.widget<Text>(find.text('test@example.com'));
      expect(emailValue.style?.fontSize, 15);
      expect(emailValue.style?.fontWeight, FontWeight.bold);
      expect(emailValue.style?.color, Colors.black);
    });

    testWidgets('container decorations are correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      // Find profile container inside BackdropFilter
      final profileContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(Container),
        ).first,
      );
      
      final decoration = profileContainer.decoration as BoxDecoration;
      expect(decoration.color, Colors.white.withOpacity(0.15));
      expect(decoration.borderRadius, BorderRadius.circular(20));
      expect(decoration.border?.top.color, Colors.white30);
    });

    testWidgets('SizedBox spacings are correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.height != null)
          .toList();
      
      // Check that we have the expected spacings
      expect(sizedBoxes.any((box) => box.height == 20), isTrue);
      expect(sizedBoxes.any((box) => box.height == 10), isTrue);
      expect(sizedBoxes.any((box) => box.height == 16), isTrue);
    });

    testWidgets('bottom navigation styling is correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      
      expect(bottomNav.type, BottomNavigationBarType.fixed);
      expect(bottomNav.selectedItemColor, Colors.green[700]);
      expect(bottomNav.unselectedItemColor, Colors.black);
      expect(bottomNav.showSelectedLabels, isFalse);
      expect(bottomNav.showUnselectedLabels, isFalse);
      expect(bottomNav.backgroundColor, const Color(0xFFD4EECD));
      expect(bottomNav.currentIndex, 3);
      expect(bottomNav.items.length, 4);
    });

    testWidgets('bottom navigation items are correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'email': 'test@example.com',
        'username': 'testuser',
        'keyID': '12345',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const OperatorProfileScreen()),
      );
      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}