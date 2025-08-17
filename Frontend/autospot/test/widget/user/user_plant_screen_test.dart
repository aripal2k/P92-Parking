import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autospot/user/userCarbonEmission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  group('UserCarbonEmissionScreen Widget Tests', () {
    // Set up consistent test viewport
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(800, 1200);
      binding.window.devicePixelRatioTestValue = 1.0;
      
      // Initialize SharedPreferences with test data
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
      });
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    // Helper function to create a mock HTTP client
    http.Client createMockClient({
      List<dynamic> emissions = const [],
      List<dynamic> sessions = const [],
    }) {
      return MockClient((request) async {
        if (request.url.path.contains('session/history')) {
          return http.Response(
            jsonEncode({'sessions': sessions}),
            200,
          );
        } else if (request.url.path.contains('emissions/history')) {
          return http.Response(
            jsonEncode({'records': emissions}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
    }

    testWidgets('displays loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays intro screen when no carbon history', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      // Wait for the loading to complete
      await tester.pumpAndSettle();

      // Assert - Check app bar
      expect(find.text('AutoSpot'), findsOneWidget);

      // Assert - Check intro content
      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(find.text('Carbon Emission Savings'), findsOneWidget);
      expect(
        find.text('Track your eco-friendly parking benefits with our smart routing system.'),
        findsOneWidget,
      );
      expect(find.text('View My Carbon Savings'), findsOneWidget);

      // Should not show back button initially
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('shows snackbar when no history and button clicked', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.text('View My Carbon Savings'));
      await tester.pump();

      // Should show snackbar
      expect(find.text('No carbon emission history found.'), findsOneWidget);
    });

    testWidgets('has correct gradient background', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Find the Container with gradient
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(gradient.colors[0], const Color(0xFFD4EECD));
      expect(gradient.colors[1], const Color(0xFFA3DB94));
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFD4EECD));
      expect(appBar.elevation, 0);
      expect(appBar.centerTitle, true);
    });

    testWidgets('eco icon has correct color and size', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      final icon = tester.widget<Icon>(find.byIcon(Icons.eco));
      expect(icon.size, 100);
      expect(icon.color, const Color(0xFF68B245));
    });

    testWidgets('button has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final buttonStyle = button.style!;

      final backgroundColor = buttonStyle.backgroundColor!.resolve({});
      expect(backgroundColor, const Color(0xFFA3DB94));
    });

    testWidgets('shows message when username not found', (WidgetTester tester) async {
      // Clear SharedPreferences
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should still show the intro screen
      expect(find.text('Carbon Emission Savings'), findsOneWidget);
      expect(find.text('View My Carbon Savings'), findsOneWidget);
    });
  });
}