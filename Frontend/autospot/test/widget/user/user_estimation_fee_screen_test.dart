import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userEstimationFee_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('EstimationFeeScreen Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('screen renders without crashing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
        'selected_date': '2024-01-01',
        'selected_time': '10:00',
        'selected_duration_in_hours': 2.0,
        'selected_hours': 2,
        'selected_minutes': 0,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      expect(find.byType(EstimationFeeScreen), findsOneWidget);
    });

    testWidgets('displays AutoSpot title', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('AutoSpot'), findsOneWidget);
    });

    testWidgets('has scaffold with correct background', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has gradient background container', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('has SafeArea widget', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('shows content after loading', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      
      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Assert - Should show content (even if API failed)
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Fare Estimation'), findsOneWidget);
    });

    testWidgets('displays fare estimation container', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('has column layout for content', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('displays divider', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('handles empty preferences gracefully', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert - Should not crash
      expect(find.byType(EstimationFeeScreen), findsOneWidget);
    });

    testWidgets('displays text widgets', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('has sized boxes for spacing', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('displays building information when available', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
        'selected_date': '2024-01-01',
        'selected_time': '10:00',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert - Building label should exist even if data loading failed
      expect(find.textContaining('Building'), findsAny);
    });

    testWidgets('shows fare estimation title', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Fare Estimation'), findsOneWidget);
    });

    testWidgets('container has blur effect', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(backdropFilter.filter, isNotNull);
    });

    testWidgets('has proper text styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert
      final autoSpotText = tester.widget<Text>(find.text('AutoSpot'));
      expect(autoSpotText.style?.fontSize, 32);
      expect(autoSpotText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('scaffold extends body', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, isTrue);
    });

    testWidgets('has stack layout', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );

      // Assert
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('formats duration when hours provided', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'selected_destination': 'Test Building',
        'selected_duration_in_hours': 2.0,
        'selected_hours': 2,
        'selected_minutes': 0,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const EstimationFeeScreen()),
      );
      await tester.pumpAndSettle();

      // Assert - Duration text should exist
      expect(find.textContaining('Duration'), findsAny);
    });
  });
}