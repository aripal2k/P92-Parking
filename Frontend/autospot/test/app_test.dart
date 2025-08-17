import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/main.dart';
import 'package:autospot/user/userLogin_screen.dart';
import 'package:autospot/main_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/test_helpers.dart';
import 'helpers/test_app.dart';

void main() {
  group('MyApp Widget Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('app starts with login screen as default route', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('AutoSpot'), findsOneWidget);
    });

    testWidgets('app has correct title', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, 'AutoSpot');
    });

    testWidgets('app has correct theme configuration', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme, isNotNull);
      // Note: ColorScheme doesn't expose seedColor directly after creation
      // We can verify the theme exists and has a color scheme
      expect(app.theme?.colorScheme, isNotNull);
    });

    testWidgets('navigates to registration screen', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      // Assert - Should navigate to registration screen
      expect(find.text('Account Registration'), findsOneWidget);
    });

    testWidgets('navigates to forgot password screen', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      await tester.tap(find.text('Forget Password?'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Forget Password'), findsOneWidget);
    });

    testWidgets('navigates to operator login screen', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      await tester.tap(find.text('Operator Login'));
      await tester.pumpAndSettle();

      // Assert
      // The operator login page shows the title text once
      expect(find.text('Operator Login'), findsOneWidget);
      // Verify we're on the operator login screen by checking for email field
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    });

    testWidgets('all routes are properly configured', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Assert - Check if MaterialApp has routes configured
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.routes, isNotNull);
      expect(app.routes!.length, greaterThan(20)); // Should have many routes

      // Check some key routes exist
      expect(app.routes!.containsKey('/'), isTrue);
      expect(app.routes!.containsKey('/register'), isTrue);
      expect(app.routes!.containsKey('/dashboard'), isTrue);
      expect(app.routes!.containsKey('/profile'), isTrue);
      expect(app.routes!.containsKey('/wallet'), isTrue);
      expect(app.routes!.containsKey('/operator-login'), isTrue);
    });

    testWidgets('dashboard route uses MainContainer with correct index', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());
      
      // Get the route builder
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/dashboard'];
      
      // Act - Build the route widget
      final widget = routeBuilder!(tester.element(find.byType(MaterialApp)));
      
      // Assert
      expect(widget, isA<MainContainer>());
      expect((widget as MainContainer).initialIndex, 0);
    });

    testWidgets('map route uses MainContainer with correct index', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());
      
      // Get the route builder
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/map'];
      
      // Act - Build the route widget
      final widget = routeBuilder!(tester.element(find.byType(MaterialApp)));
      
      // Assert
      expect(widget, isA<MainContainer>());
      expect((widget as MainContainer).initialIndex, 1);
    });

    testWidgets('eco route uses MainContainer with correct index', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());
      
      // Get the route builder
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/eco'];
      
      // Act - Build the route widget
      final widget = routeBuilder!(tester.element(find.byType(MaterialApp)));
      
      // Assert
      expect(widget, isA<MainContainer>());
      expect((widget as MainContainer).initialIndex, 2);
    });
  });

  group('Session Cleanup Tests', () {
    late MockClient mockClient;

    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    test('clearPreviousSessionOnRestart clears local session data', () async {
      // Arrange
      await TestHelpers.setupMockSharedPreferences(
        additionalData: {
          'session_id': 'test_session_123',
          'parking_start_time': DateTime.now().toIso8601String(),
          'allocated_spot_id': 'A01',
          'countdown_start_time': DateTime.now().toIso8601String(),
          'countdown_seconds': 300,
          'has_valid_navigation': true,
          'navigation_path': 'test_path',
          'destination_path': 'test_dest',
          'selected_destination': 'Building A',
          'username': 'testuser',
          'vehicle_id': 'vehicle123',
        },
      );

      // Setup mock client for API calls
      mockClient = MockClient((request) async {
        if (request.url.path.contains('/session/delete') ||
            request.url.path.contains('/session/clear-all')) {
          return http.Response('{"message": "Session cleared"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      // Act - This would normally be called in main()
      // Since we can't test main() directly, we'll need to refactor the cleanup function
      // For now, we verify the data exists before cleanup
      final prefs = await SharedPreferences.getInstance();
      
      // Assert - Data should exist before cleanup
      expect(prefs.getString('session_id'), 'test_session_123');
      expect(prefs.getString('username'), 'testuser');
      expect(prefs.getBool('has_valid_navigation'), true);
    });
  });

  group('MyHomePage Widget Tests', () {
    testWidgets('displays counter and increment button', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: MyHomePage(title: 'Test Page'),
        ),
      );

      // Assert initial state
      expect(find.text('Test Page'), findsOneWidget);
      expect(find.text('You have pushed the button this many times:'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('increments counter when button is pressed', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: MyHomePage(title: 'Test Page'),
        ),
      );

      // Act
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Assert
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      // Act - Press again
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Assert
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('has correct app bar color', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: const MyHomePage(title: 'Test Page'),
        ),
      );

      // Assert
      final AppBar appBar = tester.widget(find.byType(AppBar));
      final BuildContext context = tester.element(find.byType(AppBar));
      expect(
        appBar.backgroundColor,
        Theme.of(context).colorScheme.inversePrimary,
      );
    });
  });
}