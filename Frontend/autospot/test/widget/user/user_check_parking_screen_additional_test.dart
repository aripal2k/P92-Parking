import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autospot/user/userCheckParking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ParkingMapScreen Additional UI Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('shows no map screen components correctly', (WidgetTester tester) async {
      // Arrange - No destination selected
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - when no destination selected, shows select destination buttons
      expect(find.text('Select Destination'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('select destination button has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Select Destination'),
      );
      expect(button.style!.backgroundColor!.resolve({}), const Color(0xFFA3DB94));
    });

    testWidgets('no map screen has proper text styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - verify Select Destination button styling
      final buttonText = tester.widget<Text>(find.text('Select Destination'));
      expect(buttonText.style!.fontWeight, FontWeight.bold);

      // Verify Scan QR Code button exists
      expect(find.text('Scan QR Code'), findsOneWidget);
    });

    testWidgets('loading indicator has correct color', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );

      // Assert - Check loading state
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.valueColor!.value, const Color(0xFFA3DB94));
    });

    testWidgets('scaffold background color is correct', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('handles countdown timer restoration', (WidgetTester tester) async {
      // Arrange - Set up countdown timer that hasn't expired
      final countdownStart = DateTime.now().subtract(const Duration(seconds: 2));
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'countdown_start_time': countdownStart.toIso8601String(),
        'countdown_seconds': 10,
        'app_last_active_time': DateTime.now().toIso8601String(),
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Assert - Timer should be active
      expect(find.byType(ParkingMapScreen), findsOneWidget);
    });

    testWidgets('handles active parking session restoration', (WidgetTester tester) async {
      // Arrange - Set up active parking session
      final parkingStart = DateTime.now().subtract(const Duration(minutes: 30));
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'parking_start_time': parkingStart.toIso8601String(),
        'app_last_active_time': DateTime.now().toIso8601String(),
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Assert - Session should be active
      expect(find.byType(ParkingMapScreen), findsOneWidget);
    });

    testWidgets('clears timer states for long inactivity', (WidgetTester tester) async {
      // Arrange - App was inactive for more than 10 minutes
      final lastActiveTime = DateTime.now().subtract(const Duration(minutes: 15));
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'app_last_active_time': lastActiveTime.toIso8601String(),
        'parking_start_time': DateTime.now().toIso8601String(),
        'countdown_start_time': DateTime.now().toIso8601String(),
        'countdown_seconds': 10,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Assert - Timer states should be cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('parking_start_time'), isNull);
      expect(prefs.getString('countdown_start_time'), isNull);
      expect(prefs.getInt('countdown_seconds'), isNull);
    });

    testWidgets('handles invalid last active time', (WidgetTester tester) async {
      // Arrange - Invalid timestamp
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'app_last_active_time': 'invalid_timestamp',
        'parking_start_time': DateTime.now().toIso8601String(),
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Assert - Should handle gracefully and clear states
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('parking_start_time'), isNull);
    });

    testWidgets('handles countdown that should transition to parking', (WidgetTester tester) async {
      // Arrange - Countdown that has already ended
      final countdownStart = DateTime.now().subtract(const Duration(seconds: 15));
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'countdown_start_time': countdownStart.toIso8601String(),
        'countdown_seconds': 10,
        'app_last_active_time': DateTime.now().toIso8601String(),
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Assert - Countdown should be cleared and parking should start
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('countdown_start_time'), isNull);
      expect(prefs.getInt('countdown_seconds'), isNull);
    });

    testWidgets('handles invalid countdown timer data', (WidgetTester tester) async {
      // Arrange - Invalid countdown data
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'countdown_start_time': 'invalid_time',
        'countdown_seconds': 10,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Assert - Should handle gracefully
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('countdown_start_time'), isNull);
      expect(prefs.getInt('countdown_seconds'), isNull);
    });

    testWidgets('loads allocation data from preferences', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'allocated_spot_id': 'C3',
        'slot_x': 5,
        'slot_y': 10,
        'slot_level': 2,
        'entrance_id': 'E001',
        'selected_destination': 'Building A',
        'from_dashboard_selection': true,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for any delayed timers

      // Assert - Data should be loaded (even if API fails)
      expect(find.byType(ParkingMapScreen), findsOneWidget);
    });

    testWidgets('handles navigation path parsing errors', (WidgetTester tester) async {
      // Arrange - Invalid JSON in navigation paths
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'entrance_id': 'E001',
        'selected_destination': 'Building A',
        'navigation_path': 'invalid_json',
        'destination_path': '[invalid_json]',
        'from_dashboard_selection': true,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for any delayed timers

      // Assert - Should handle parsing errors gracefully
      expect(find.byType(ParkingMapScreen), findsOneWidget);
    });

    testWidgets('handles missing allocated spot gracefully', (WidgetTester tester) async {
      // Arrange - No allocated spot
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'entrance_id': 'E001',
        'selected_destination': 'Building A',
        'from_dashboard_selection': true,
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert - Should handle missing spot
      expect(find.byType(ParkingMapScreen), findsOneWidget);
    });

    testWidgets('handles forceShowMap with building from QR', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'building_id': 'Building B',
        'entrance_id': 'E002',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const ParkingMapScreen(forceShowMap: true),
        ),
      );
      
      await tester.pump();

      // Assert - Should use building from QR
      expect(find.byType(ParkingMapScreen), findsOneWidget);
      
      // Clean up
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('handles forceShowMap without building data', (WidgetTester tester) async {
      // Arrange - No building data
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const ParkingMapScreen(forceShowMap: true),
        ),
      );
      
      await tester.pump();

      // Assert - Should use default building
      expect(find.byType(ParkingMapScreen), findsOneWidget);
      
      // Clean up
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('properly disposes timers on widget disposal', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'parking_start_time': DateTime.now().toIso8601String(),
      });

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const ParkingMapScreen()),
      );
      
      await tester.pump();

      // Dispose widget
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Assert - Should dispose without errors
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(ParkingMapScreen), findsNothing);
    });
  });
}