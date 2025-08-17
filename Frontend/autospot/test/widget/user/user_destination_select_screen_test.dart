import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/user/userDestinationSelect_screen.dart';

void main() {
  late SharedPreferences mockPrefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
  });

  void setLargeScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.resetDevicePixelRatio();
  });

  group('DestinationSelectScreen Tests', () {
    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('shows error message when no entrance data', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      // No entrance_id set

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No entrance data found. Please scan a valid entrance QR code.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('displays entrance information when available', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');
      await mockPrefs.setString('building_id', 'Building A');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      // Wait for destinations to load (uses fallback data)
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Entrance Detected'), findsOneWidget);
      expect(find.text('ID: E001'), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('displays destination list after loading', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      // Wait for destinations to load
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Check for fallback destinations
      expect(find.text('Select Your Destination:'), findsOneWidget);
      expect(find.text('Westfield Sydney'), findsOneWidget);
      expect(find.text('Building Entrance (BE1)'), findsOneWidget);
      expect(find.text('Exit (X1)'), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('can select a destination', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Tap on a destination
      await tester.tap(find.text('Westfield Sydney'));
      await tester.pump();

      // Should show check mark on selected item
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('shows Find Best Parking Spot button', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Find Best Parking Spot'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(1));
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('app bar has correct title and styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      expect(find.text('Select Destination'), findsOneWidget);
      
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFA3DB94));
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('scaffold has correct background color', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('card styling changes when selected', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Find first card before selection
      final cardBeforeSelection = tester.widget<Card>(find.byType(Card).first);
      expect(cardBeforeSelection.color, Colors.white);
      expect(cardBeforeSelection.elevation, 1);

      // Select the first destination
      await tester.tap(find.text('Westfield Sydney'));
      await tester.pump();

      // Card should now be selected
      final cardAfterSelection = tester.widget<Card>(find.byType(Card).first);
      expect(cardAfterSelection.color, const Color(0xFFA3DB94));
      expect(cardAfterSelection.elevation, 4);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('destination list is scrollable', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify ListView is present
      expect(find.byType(ListView), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('entrance container has proper styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Find the container with entrance info
      final containerFinder = find.ancestor(
        of: find.text('Entrance Detected'),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(containerFinder);
      expect(container.decoration, isA<BoxDecoration>());
      
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(12));
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('shows circular progress indicator with correct color', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      
      final valueColor = progressIndicator.valueColor as AlwaysStoppedAnimation<Color>;
      expect(valueColor.value, const Color(0xFFA3DB94));
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('back button is present', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('entrance_id', 'E001');

      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationSelectScreen(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      
      // Clean up timer
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}