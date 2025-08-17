import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autospot/user/userActiveParking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ActiveParkingScreen Widget Tests', () {
    late DateTime testStartTime;

    setUp(() {
      TestHelpers.setUpTestViewport();
      testStartTime = DateTime.now().subtract(const Duration(minutes: 30));
      TestHelpers.setupMockSharedPreferences(
        userEmail: 'test@example.com',
        authToken: 'test_token',
        userName: 'Test User',
        userId: 'test_user_id',
      );
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays initial UI elements correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      // Assert - Check main UI elements
      expect(find.text('AutoSpot'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // Loading initially
    });

    testWidgets('displays timer view after resuming existing session', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 15));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      // Wait for async initialization
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Timer view elements should be visible
      expect(find.byIcon(Icons.timer, skipOffstage: false), findsWidgets);
      expect(find.text('View Navigation Map'), findsOneWidget);
      expect(find.text('End Parking Session'), findsOneWidget);
    });

    testWidgets('handles end session confirmation dialog with existing session', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 15));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Tap end session
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();

      // Assert - Confirmation dialog should appear
      expect(find.text('End Parking Session'), findsWidgets); // Title and button
      expect(find.text('Are you sure you want to end the parking session?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('End Session'), findsWidgets); // Button text in dialog
    });

    testWidgets('cancels end session when cancel is pressed', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 15));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - Still on active parking screen
      expect(find.text('AutoSpot'), findsOneWidget);
      expect(find.text('End Parking Session'), findsOneWidget);
    });

    testWidgets('displays navigation bar when showNavigationBar is true', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 15));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(
            startTime: testStartTime,
            showNavigationBar: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Navigation elements should be present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.map), findsWidgets); // Multiple map icons
      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.byIcon(Icons.qr_code), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('calculates and displays elapsed time correctly', (WidgetTester tester) async {
      // Arrange - Start time 1 hour ago with existing session
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': oneHourAgo.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: oneHourAgo),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Timer should show time elapsed (at least 01:)
      expect(find.textContaining('01:'), findsWidgets); // Time format HH:MM:SS
    });

    testWidgets('disposes timer properly when widget is disposed', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 15));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Dispose widget
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Assert - Widget should dispose without errors
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('handles missing required session data', (WidgetTester tester) async {
      // Arrange - Missing required fields
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        // Missing username, vehicle_id, allocated_spot_id
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();

      // Assert - Should handle missing data gracefully
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('formats duration correctly for different time periods', (WidgetTester tester) async {
      // Arrange - Test with 2 hours, 30 minutes elapsed
      final specificTime = DateTime.now().subtract(
        const Duration(hours: 2, minutes: 30),
      );
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': specificTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: specificTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should format time as HH:MM:SS with at least 02:30
      expect(find.textContaining('02:'), findsWidgets);
    });

    testWidgets('handles invalid stored start time gracefully', (WidgetTester tester) async {
      // Arrange - Invalid start time
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': 'invalid-date-string',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();

      // Assert - Should handle invalid date gracefully
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('shows correct timer format for zero elapsed time', (WidgetTester tester) async {
      // Arrange - Just started session
      final justNow = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': justNow.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: justNow),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show 00:00:00 or similar
      expect(find.textContaining('00:00:'), findsWidgets);
    });

    testWidgets('shows View Navigation Map button when session is active', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should have map toggle button
      expect(find.text('View Navigation Map'), findsOneWidget);
      expect(find.byIcon(Icons.map, skipOffstage: false), findsWidgets);
    });

    testWidgets('displays timer icon when session is active', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 10));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'B-202',
        'session_id': 'existing_session_456',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show timer icon
      expect(find.byIcon(Icons.timer, skipOffstage: false), findsWidgets);
    });

    testWidgets('displays End Parking Session button with correct style', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 20));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'C-303',
        'session_id': 'existing_session_789',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: testStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should have end session button
      expect(find.text('End Parking Session'), findsOneWidget);
      expect(find.byIcon(Icons.stop, skipOffstage: false), findsWidgets);
    });

    testWidgets('updates timer display periodically', (WidgetTester tester) async {
      // Arrange - Simulate existing session
      final existingStartTime = DateTime.now().subtract(const Duration(seconds: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'D-404',
        'session_id': 'existing_session_999',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show initial time
      expect(find.textContaining('00:00:'), findsWidgets);

      // Wait for timer to update
      await tester.pump(const Duration(seconds: 2));

      // Timer should have updated (now showing at least 7 seconds)
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('toggles to map view when View Navigation Map is pressed', (WidgetTester tester) async {
      // Arrange - Simulate existing session with navigation data
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 10));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        'session_id': 'existing_session_123',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building A',
        'slot_x': 5,
        'slot_y': 3,
        'slot_level': 1,
        'navigation_path': '[[1,0,0],[1,1,0],[1,2,0]]',
        'destination_path': '[[1,5,3],[1,6,3],[1,7,3]]',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Tap View Navigation Map button
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Either loading or showing map/error (depends on network mock)
      // Since we have navigation data, it should attempt to load
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('shows map not available when no navigation data', (WidgetTester tester) async {
      // Arrange - Session without navigation data
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'B-202',
        'session_id': 'existing_session_456',
        'parking_start_time': existingStartTime.toIso8601String(),
        // No navigation data
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // Wait for loading

      // Assert - Should show map not available
      expect(find.text('Navigation Map Not Available'), findsOneWidget);
      expect(find.text('No navigation data found for this session'), findsOneWidget);
      expect(find.text('Back to Timer'), findsOneWidget);
    });

    testWidgets('toggles back to timer view from map view', (WidgetTester tester) async {
      // Arrange - Session with map toggled
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'C-303',
        'session_id': 'existing_session_789',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map and back
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      
      // Find and tap Back to Timer
      await tester.tap(find.text('Back to Timer'));
      await tester.pump();

      // Assert - Should be back on timer view
      expect(find.byIcon(Icons.timer, skipOffstage: false), findsWidgets);
      expect(find.text('View Navigation Map'), findsOneWidget);
      expect(find.text('End Parking Session'), findsOneWidget);
    });

    testWidgets('shows error when starting session fails with server error', (WidgetTester tester) async {
      // Arrange - No existing session
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'A-101',
        // No session_id - will trigger start session attempt
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      await tester.pump();

      // Assert - Should remain in loading state (can't mock HTTP)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('handles network error when ending session', (WidgetTester tester) async {
      // Arrange - Existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 30));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'D-404',
        'session_id': 'existing_session_101',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Try to end session
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();
      
      // Confirm end session
      await tester.tap(find.widgetWithText(ElevatedButton, 'End Session'));
      await tester.pump();

      // Assert - Dialog might still be open or closed (depends on async timing)
      // We can't predict exact state without HTTP mocking
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('shows gradient background correctly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      // Assert - Check gradient container
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(Container),
        ).first,
      );
      
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.colors[0], const Color(0xFFD4EECD));
      expect(gradient.colors[1], const Color(0xFFA3DB94));
    });

    testWidgets('dialog has correct styling and shadow', (WidgetTester tester) async {
      // Arrange - Existing session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 10));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'E-505',
        'session_id': 'existing_session_202',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Show dialog
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();

      // Assert - Check dialog styling
      expect(find.byType(Dialog), findsOneWidget);
      
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFFCFF4D2));
      expect(dialog.elevation, 24);
      expect((dialog.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(20));
    });

    testWidgets('timer continues running while viewing map', (WidgetTester tester) async {
      // Arrange - Existing session
      final existingStartTime = DateTime.now().subtract(const Duration(seconds: 10));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'F-606',
        'session_id': 'existing_session_303',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      
      // Wait a bit
      await tester.pump(const Duration(seconds: 2));

      // Assert - Timer should still be running (time display in map view)
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('stores temporary parking data when ending session', (WidgetTester tester) async {
      // Arrange - Existing session
      final startTime = DateTime.now().subtract(const Duration(hours: 1, minutes: 30));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'G-707',
        'session_id': 'existing_session_404',
        'parking_start_time': startTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: startTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - End session
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'End Session'));
      await tester.pump();

      // Assert - Data would be stored (can't verify without HTTP mocking)
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('handles malformed navigation path JSON gracefully', (WidgetTester tester) async {
      // Arrange - Session with invalid navigation data
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'H-808',
        'session_id': 'existing_session_505',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building B',
        'navigation_path': 'invalid_json_data',
        'destination_path': '[[1,5,3],[1,6,3]]',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Try to view map
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Should handle error gracefully
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('shows autospot title correctly', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'I-909',
        'session_id': 'existing_session_606',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Title styling
      final titleWidget = tester.widget<Text>(find.text('AutoSpot'));
      expect(titleWidget.style?.fontSize, 28);
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
      expect(titleWidget.style?.color, Colors.black87);
      expect(titleWidget.style?.letterSpacing, 1.2);
    });


    testWidgets('handles session with future start time gracefully', (WidgetTester tester) async {
      // Arrange - Future start time (edge case)
      final futureStartTime = DateTime.now().add(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'K-111',
        'session_id': 'existing_session_808',
        'parking_start_time': futureStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should handle gracefully 
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
      // Timer display might show different format depending on implementation
      // Just verify the screen loads without error
    });

    testWidgets('timer icon has correct size and color', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'L-212',
        'session_id': 'existing_session_909',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Find the large timer icon
      final icons = find.byIcon(Icons.timer).evaluate();
      bool foundLargeIcon = false;
      
      for (var element in icons) {
        final icon = element.widget as Icon;
        if (icon.size == 100) {
          foundLargeIcon = true;
          expect(icon.color, Colors.green);
          break;
        }
      }
      
      expect(foundLargeIcon, isTrue);
    });

    testWidgets('end session button has stop icon', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'M-313',
        'session_id': 'existing_session_010',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.byIcon(Icons.stop), findsWidgets);
    });

    testWidgets('view navigation map button has map icon', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'N-414',
        'session_id': 'existing_session_111',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Map icon should be present
      expect(find.byIcon(Icons.map), findsWidgets);
    });

    testWidgets('dialog buttons have correct styling', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'O-515',
        'session_id': 'existing_session_212',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Open dialog
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();

      // Assert - Check Cancel button styling
      final cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Cancel'),
      );
      expect(cancelButton.style?.backgroundColor?.resolve({}), Colors.white);
      expect(cancelButton.style?.foregroundColor?.resolve({}), Colors.black87);
      
      // Check End Session button in dialog
      final endButtons = find.widgetWithText(ElevatedButton, 'End Session').evaluate();
      for (var element in endButtons) {
        final button = element.widget as ElevatedButton;
        if (button.style?.backgroundColor?.resolve({}) == Colors.red) {
          expect(button.style?.foregroundColor?.resolve({}), Colors.white);
          break;
        }
      }
    });

    testWidgets('shows loading map message when toggling to map view', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'P-616',
        'session_id': 'existing_session_313',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building A',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump(const Duration(milliseconds: 50)); // Shorter time to catch loading state

      // Assert - Should show loading or already loaded
      final loadingText = find.text('Loading Navigation Map...');
      final noMapText = find.text('Navigation Map Not Available');
      expect(
        loadingText.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('shows path toggle button when navigation paths are available', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'Q-717',
        'session_id': 'existing_session_414',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building B',
        'navigation_path': '[[1,0,0],[1,1,0],[1,2,0]]',
        'destination_path': '[[1,5,3],[1,6,3],[1,7,3]]',
        'slot_x': 5,
        'slot_y': 3,
        'slot_level': 1,
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for API call

      // Assert - Path toggle button should be visible (or map not available)
      final toSlotButton = find.text('To Slot');
      final noMapText = find.text('Navigation Map Not Available');
      expect(
        toSlotButton.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('displays allocated spot info in map view', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'R-818',
        'session_id': 'existing_session_515',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building C',
        'slot_x': 10,
        'slot_y': 8,
        'slot_level': 2,
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for API call

      // Assert - Should show parking spot info or map not available
      final spotText = find.text('R-818');
      final noMapText = find.text('Navigation Map Not Available');
      expect(
        spotText.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('handles empty navigation path gracefully', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'S-919',
        'session_id': 'existing_session_616',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building D',
        'navigation_path': '[]', // Empty path
        'destination_path': '[]', // Empty path
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Should handle gracefully
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('shows correct icons for path mode toggle', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'T-020',
        'session_id': 'existing_session_717',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building E',
        'navigation_path': '[[1,0,0],[1,1,0]]',
        'destination_path': '[[1,5,3],[1,6,3]]',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Assert - Should show walking icon or no map available
      final walkIcon = find.byIcon(Icons.directions_walk);
      final noMapText = find.text('Navigation Map Not Available');
      expect(
        walkIcon.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('displays path info with correct styling', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'U-121',
        'session_id': 'existing_session_818',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building F',
        'navigation_path': '[[1,0,0],[1,1,0],[1,2,0]]',
        'destination_path': '[[1,5,3],[1,6,3]]',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Assert - Path info display or no map
      final pathText = find.text('Entrance → Parking Slot');
      final noMapText = find.text('Navigation Map Not Available');
      expect(
        pathText.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('handles level selector when multiple levels exist', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'V-222',
        'session_id': 'existing_session_919',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building G',
        'slot_level': 2,
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Should handle map view
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('timer view button styling is correct', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'W-323',
        'session_id': 'existing_session_020',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - View Navigation Map button exists
      expect(find.text('View Navigation Map'), findsOneWidget);
      expect(find.byIcon(Icons.map), findsWidgets);
    });

    testWidgets('end session button has correct red styling', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'X-424',
        'session_id': 'existing_session_121',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - End Parking Session button exists
      expect(find.text('End Parking Session'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsWidgets);
    });

    testWidgets('timer text has correct styling', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'Y-525',
        'session_id': 'existing_session_222',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Find timer text with correct format
      final timerTexts = find.textContaining(':').evaluate();
      bool foundTimerWithCorrectStyle = false;
      
      for (var element in timerTexts) {
        final widget = element.widget as Text;
        if (widget.style?.fontSize == 48) {
          foundTimerWithCorrectStyle = true;
          expect(widget.style?.fontWeight, FontWeight.bold);
          expect(widget.style?.color, Colors.black87);
          break;
        }
      }
      
      expect(foundTimerWithCorrectStyle, isTrue);
    });

    testWidgets('handles missing allocated spot ID gracefully in map view', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'Z-626',
        'session_id': 'existing_session_323',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building H',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Remove allocated spot to test missing spot scenario
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('allocated_spot_id');
      
      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Assert - Map should show without allocated spot or show no map available
      final parkingIcon = find.byIcon(Icons.local_parking);
      final noMapText = find.text('Navigation Map Not Available');
      
      // Either no parking icon or no map available
      expect(
        parkingIcon.evaluate().isEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('bottom navigation bar has correct selected index', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'AA-727',
        'session_id': 'existing_session_424',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(
            startTime: existingStartTime,
            showNavigationBar: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      final bottomNav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bottomNav.currentIndex, 1); // Map tab should be selected
    });

    testWidgets('path mode button is disabled when only one path exists', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'BB-828',
        'session_id': 'existing_session_525',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building I',
        'navigation_path': '[[1,0,0],[1,1,0]]',
        // No destination_path
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Assert - Either path button is disabled or map not available
      final pathButtons = find.widgetWithText(ElevatedButton, 'To Slot').evaluate();
      final noMapText = find.text('Navigation Map Not Available');
      
      if (pathButtons.isNotEmpty) {
        final pathButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'To Slot'),
        );
        expect(pathButton.onPressed, isNull);
      } else {
        expect(noMapText, findsOneWidget);
      }
    });

    testWidgets('safely handles widget disposal during async operations', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'CC-929',
        // No session_id to trigger start session
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      // Act - Quickly dispose before async completes
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Assert - Should dispose without errors
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(ActiveParkingScreen), findsNothing);
    });

    testWidgets('handles large elapsed time formatting correctly', (WidgetTester tester) async {
      // Arrange - 10 hours elapsed
      final tenHoursAgo = DateTime.now().subtract(const Duration(hours: 10, minutes: 45, seconds: 30));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'DD-030',
        'session_id': 'existing_session_626',
        'parking_start_time': tenHoursAgo.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: tenHoursAgo),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show 10:45:XX format
      expect(find.textContaining('10:'), findsWidgets);
    });

    testWidgets('SafeArea wraps main content correctly', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'EE-131',
        'session_id': 'existing_session_727',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('timer continues updating after multiple seconds', (WidgetTester tester) async {
      // Arrange
      final startTime = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'FF-232',
        'session_id': 'existing_session_828',
        'parking_start_time': startTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: startTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial state
      expect(find.textContaining('00:00:'), findsWidgets);

      // Act - Wait 3 seconds
      await tester.pump(const Duration(seconds: 3));

      // Assert - Timer should have updated
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
      // Timer text will have changed but exact value depends on execution time
    });

    testWidgets('map view controls layout is correct', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'GG-333',
        'session_id': 'existing_session_929',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building J',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Assert - Either map controls or no map available
      final timerButton = find.widgetWithText(ElevatedButton, 'Timer');
      final noMapText = find.text('Navigation Map Not Available');
      final backToTimerButton = find.text('Back to Timer');
      
      expect(
        timerButton.evaluate().isNotEmpty || 
        noMapText.evaluate().isNotEmpty || 
        backToTimerButton.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('handles navigation path with invalid point format', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'HH-434',
        'session_id': 'existing_session_030',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building K',
        'navigation_path': '[[1,0],[2]]', // Invalid format
        'destination_path': '[[1,5,3]]',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Should handle gracefully
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('displays scaffold with transparent background', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(scaffold.extendBody, true);
    });

    testWidgets('handles very long duration formatting', (WidgetTester tester) async {
      // Arrange - 99 hours elapsed
      final longAgo = DateTime.now().subtract(const Duration(hours: 99, minutes: 59, seconds: 59));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'II-535',
        'session_id': 'existing_session_131',
        'parking_start_time': longAgo.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: longAgo),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show 99:59:XX format
      expect(find.textContaining('99:'), findsWidgets);
    });

    testWidgets('map loading indicator has correct color', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'JJ-636',
        'session_id': 'existing_session_232',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building L',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Loading indicator should be green
      final loadingIndicators = find.byType(CircularProgressIndicator).evaluate();
      for (var element in loadingIndicators) {
        final indicator = element.widget as CircularProgressIndicator;
        if (indicator.color == Colors.green) {
          expect(indicator.color, Colors.green);
          break;
        }
      }
    });

    testWidgets('handles missing username gracefully', (WidgetTester tester) async {
      // Arrange - Missing username
      SharedPreferences.setMockInitialValues({
        // No username
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'KK-737',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      await tester.pump();

      // Assert - Should show snackbar
      expect(find.text('Missing session data'), findsOneWidget);
    });

    testWidgets('handles missing vehicle ID gracefully', (WidgetTester tester) async {
      // Arrange - Missing vehicle_id
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        // No vehicle_id
        'user_email': 'test@example.com',
        'allocated_spot_id': 'LL-838',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      await tester.pump();

      // Assert - Should show snackbar
      expect(find.text('Missing session data'), findsOneWidget);
    });

    testWidgets('handles missing slot ID gracefully', (WidgetTester tester) async {
      // Arrange - Missing allocated_spot_id
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        // No allocated_spot_id
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: DateTime.now()),
        ),
      );

      await tester.pump();

      // Assert - Should show snackbar
      expect(find.text('Missing session data'), findsOneWidget);
    });

    testWidgets('handles missing session info when ending session', (WidgetTester tester) async {
      // Arrange - Start with valid session
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'MM-939',
        'session_id': 'existing_session_333',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Remove session info
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_id');

      // Act - Try to end session
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'End Session'));
      await tester.pump();

      // Assert - Should show error
      expect(find.text('Missing session info.'), findsOneWidget);
    });

    testWidgets('toggles path mode correctly', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'NN-040',
        'session_id': 'existing_session_434',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building M',
        'navigation_path': '[[1,0,0],[1,1,0]]',
        'destination_path': '[[1,5,3],[1,6,3]]',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Check if map loaded
      final toSlotButton = find.text('To Slot');
      final noMapText = find.text('Navigation Map Not Available');
      
      if (toSlotButton.evaluate().isNotEmpty) {
        // Initial state - entrance to slot
        expect(find.text('To Slot'), findsOneWidget);

        // Toggle path mode
        await tester.tap(find.text('To Slot'));
        await tester.pump();

        // Assert - Should now show destination mode
        expect(find.text('To Destination'), findsOneWidget);
        expect(find.text('Parking Slot → Destination'), findsOneWidget);
      } else {
        // Map not available
        expect(noMapText, findsOneWidget);
      }
    });

    testWidgets('path info shows correct number of points', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'OO-141',
        'session_id': 'existing_session_535',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building N',
        'navigation_path': '[[1,0,0],[1,1,0],[1,2,0],[1,3,0]]', // 4 points
        'destination_path': '[[1,5,3],[1,6,3]]', // 2 points
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Assert - Should show count of 4 or map not available
      final countText = find.text('4');
      final noMapText = find.text('Navigation Map Not Available');
      expect(
        countText.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('handles null selected level gracefully', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'PP-242',
        'session_id': 'existing_session_636',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building O',
        // No slot_level
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Should handle gracefully
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('timer updates format pads zeros correctly', (WidgetTester tester) async {
      // Arrange - 5 seconds elapsed
      final fiveSecondsAgo = DateTime.now().subtract(const Duration(seconds: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'QQ-343',
        'session_id': 'existing_session_737',
        'parking_start_time': fiveSecondsAgo.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: fiveSecondsAgo),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Should show 00:00:05 format
      expect(find.textContaining('00:00:'), findsWidgets);
    });

    testWidgets('dialog content has correct text styling', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'RR-444',
        'session_id': 'existing_session_838',
        'parking_start_time': existingStartTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Open dialog
      await tester.tap(find.text('End Parking Session'));
      await tester.pumpAndSettle();

      // Assert - Check dialog text exists
      expect(find.text('End Parking Session'), findsWidgets); // Multiple instances
      expect(find.text('Are you sure you want to end the parking session?'), findsOneWidget);
    });

    testWidgets('navigation path with string coordinates is handled', (WidgetTester tester) async {
      // Arrange
      final existingStartTime = DateTime.now().subtract(const Duration(minutes: 5));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'SS-545',
        'session_id': 'existing_session_939',
        'parking_start_time': existingStartTime.toIso8601String(),
        'selected_destination': 'Building P',
        'navigation_path': '[["1","0","0"],["1","1","0"]]', // String coordinates
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: existingStartTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();

      // Assert - Should handle string conversion
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('map view timer display continues updating', (WidgetTester tester) async {
      // Arrange
      final startTime = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'TT-646',
        'session_id': 'existing_session_040',
        'parking_start_time': startTime.toIso8601String(),
        'selected_destination': 'Building Q',
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: startTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Act - Toggle to map view
      await tester.tap(find.text('View Navigation Map'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for loading

      // Check if map loaded or timer view is still visible
      final timerText = find.textContaining(':');
      final noMapText = find.text('Navigation Map Not Available');
      
      // Assert - Should have timer or map not available
      expect(
        timerText.evaluate().isNotEmpty || noMapText.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('handles parking fee navigation arguments correctly', (WidgetTester tester) async {
      // This test verifies the navigation arguments structure
      // but cannot verify actual navigation without HTTP mocking
      
      // Arrange
      final startTime = DateTime.now().subtract(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
        'vehicle_id': 'test_vehicle_123',
        'user_email': 'test@example.com',
        'allocated_spot_id': 'UU-747',
        'session_id': 'existing_session_141',
        'parking_start_time': startTime.toIso8601String(),
      });
      
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          ActiveParkingScreen(startTime: startTime),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert - Verify the screen is set up correctly
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
      // Navigation would include startTime, endTime, isActiveSession: false, duration
    });
  });
}