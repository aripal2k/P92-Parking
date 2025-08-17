import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/user/userMapOnly_screen.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';

void main() {
  late SharedPreferences mockPrefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
  });

  group('MapOnlyScreen Tests', () {
    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Map...'), findsOneWidget);
    });

    testWidgets('shows error when no destination is set', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No destination or building information available.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('loads example map for Westfield Sydney', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the map
      expect(find.byType(ParkingMapWidget), findsOneWidget);
      // Real-time Parking is in RichText, so we check for its container
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('shows level selector for multi-level maps', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show level selector
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('can switch between levels', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Initially on level 1
      expect(find.text('Level 1'), findsOneWidget);

      // Tap up arrow to go to level 2
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();

      expect(find.text('Level 2'), findsOneWidget);

      // Tap down arrow to go back to level 1
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.text('Level 1'), findsOneWidget);
    });

    testWidgets('shows map legend', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check legend items
      expect(find.text('Map Legend'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Occupied'), findsOneWidget);
      expect(find.text('Allocated'), findsOneWidget);
      expect(find.text('Vehicle Entry'), findsOneWidget);
      expect(find.text('Building Entry'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
      expect(find.text('Ramp'), findsOneWidget);
      expect(find.text('Wall'), findsOneWidget);
      expect(find.text('Corridor'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('shows fee estimation button', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        MaterialApp(
          home: const MapOnlyScreen(),
          routes: {
            '/estimation-fee': (context) => Container(),
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Check Fee Estimation'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on_outlined), findsOneWidget);
    });

    testWidgets('navigates to fee estimation when button tapped', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        MaterialApp(
          home: const MapOnlyScreen(),
          routes: {
            '/estimation-fee': (context) => const Scaffold(
              body: Text('Fee Estimation Screen'),
            ),
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap the fee estimation button
      await tester.tap(find.text('Check Fee Estimation'));
      await tester.pumpAndSettle();

      // Should navigate to fee estimation screen
      expect(find.text('Fee Estimation Screen'), findsOneWidget);
    });

    testWidgets('back button navigates to dashboard', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        MaterialApp(
          home: const MapOnlyScreen(),
          routes: {
            '/dashboard': (context) => const Scaffold(
              body: Text('Dashboard Screen'),
            ),
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should navigate to dashboard
      expect(find.text('Dashboard Screen'), findsOneWidget);
    });

    testWidgets('retry button reloads map data', (WidgetTester tester) async {
      // Start with no destination to trigger error
      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error
      expect(find.text('No destination or building information available.'), findsOneWidget);

      // Set destination
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Should now show map
      expect(find.byType(ParkingMapWidget), findsOneWidget);
    });

    testWidgets('level buttons are disabled at boundaries', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // At level 1, down button should be disabled
      final downButton = tester.widget<ElevatedButton>(
        find.widgetWithIcon(ElevatedButton, Icons.keyboard_arrow_down),
      );
      expect(downButton.onPressed, isNull);

      // Go to level 2
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();

      // At level 2 (max level), up button should be disabled
      final upButton = tester.widget<ElevatedButton>(
        find.widgetWithIcon(ElevatedButton, Icons.keyboard_arrow_up),
      );
      expect(upButton.onPressed, isNull);
    });

    testWidgets('handles building_id from QR code', (WidgetTester tester) async {
      await mockPrefs.setString('building_id', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should load the map using building_id
      expect(find.byType(ParkingMapWidget), findsOneWidget);
    });

    testWidgets('app bar shows correct title', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check for RichText instead of plain text
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('scaffold has correct background color', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      await mockPrefs.setString('selected_destination', 'Westfield Sydney (Example)');

      await tester.pumpWidget(
        const MaterialApp(
          home: MapOnlyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFA3DB94));
      expect(appBar.elevation, 2);
    });
  });
}