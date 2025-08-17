import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userCarbonEmission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserCarbonEmissionScreen Tests', () {
    setUp(() {
      // Initialize SharedPreferences with test data
      SharedPreferences.setMockInitialValues({
        'username': 'testuser',
      });
    });

    // Mock emission records for testing
    final mockEmissionRecords = [
      {
        'session_info': {'session_id': '1'},
        'map_info': {'building_name': 'Westfield Sydney'},
        'created_at': '2025-07-21T10:00:00',
        'emissions_saved': 120.5,
        'percentage_saved': 35,
        'calculation_method': 'Dynamic',
        'message': 'Great job! You saved emissions by using AutoSpot.',
      },
      {
        'session_info': {'session_id': '2'},
        'map_info': {'building_name': 'Central Park'},
        'created_at': '2025-07-20T14:00:00',
        'emissions_saved': 98.3,
        'percentage_saved': 28,
        'calculation_method': 'Static',
        'message': 'Your eco-friendly parking choice makes a difference!',
      },
      {
        'session_info': {'session_id': '3'},
        'map_info': {'building_name': 'Broadway Plaza'},
        'created_at': '2025-07-19T09:00:00',
        'emissions_saved': 143.7,
        'percentage_saved': 42,
        'calculation_method': 'Dynamic',
        'message': 'Excellent! You are helping reduce carbon emissions.',
      },
    ];

    testWidgets('renders intro page initially with loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for loading to complete
      await tester.pumpAndSettle();

      // Verify app bar
      expect(find.text('AutoSpot'), findsOneWidget);
      
      // Verify intro content
      expect(find.text('Carbon Emission Savings'), findsOneWidget);
      expect(find.byIcon(Icons.eco), findsOneWidget);
      expect(
        find.text('Track your eco-friendly parking benefits with our smart routing system.'),
        findsOneWidget,
      );
      
      // Verify button
      expect(find.text('View My Carbon Savings'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('shows snackbar when no history available', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the button when no history
      await tester.tap(find.text('View My Carbon Savings'));
      await tester.pump();

      // Should show snackbar
      expect(find.text('No carbon emission history found.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFD4EECD));
      expect(appBar.elevation, 0);
      expect(appBar.centerTitle, true);
    });

    testWidgets('eco icon has correct properties', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.eco);
      expect(iconFinder, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconFinder);
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

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final buttonStyle = button.style!;
      
      // Verify button color
      final backgroundColor = buttonStyle.backgroundColor!.resolve({});
      expect(backgroundColor, const Color(0xFFA3DB94));
    });

    testWidgets('gradient background is applied correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, [
        const Color(0xFFD4EECD),
        const Color(0xFFA3DB94),
      ]);
    });

    testWidgets('handles missing username gracefully', (WidgetTester tester) async {
      // Clear SharedPreferences
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: UserCarbonEmissionScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should still show intro screen
      expect(find.text('Carbon Emission Savings'), findsOneWidget);
      expect(find.text('View My Carbon Savings'), findsOneWidget);
    });
  });
}