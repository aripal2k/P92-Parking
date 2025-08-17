import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autospot/widgets/parkingMap/legend.dart';

void main() {
  group('ParkingMapLegend Widget Tests', () {
    testWidgets('displays all parking spot types in legend', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingMapLegend())),
      );

      // Assert - Check title
      expect(find.text('Map Legend'), findsOneWidget);

      // Assert - Check all legend items
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Allocated'), findsOneWidget);
      expect(find.text('Occupied'), findsOneWidget);
      expect(find.text('Vehicle Entrance'), findsOneWidget);
      expect(find.text('Building Entrance'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
      expect(find.text('Ramp'), findsOneWidget);
      expect(find.text('Wall'), findsOneWidget);
      expect(find.text('Corridor'), findsOneWidget);
      expect(find.text('Navigation Path'), findsOneWidget);
      expect(find.text('To Destination'), findsOneWidget);
    });

    testWidgets('shows trigger button by default', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingMapLegend())),
      );

      // Assert
      expect(find.text('Trigger Parking'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('hides trigger button when showTrigger is false', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ParkingMapLegend(showTrigger: false)),
        ),
      );

      // Assert
      expect(find.text('Trigger Parking'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('shows end button when showEndButton is true', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ParkingMapLegend(showEndButton: true)),
        ),
      );

      // Assert
      expect(find.text('End Parking'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('displays timer when timerText is provided', (
      WidgetTester tester,
    ) async {
      // Arrange
      const timerText = 'Time remaining: 5:30';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ParkingMapLegend(timerText: timerText)),
        ),
      );

      // Assert
      expect(find.text(timerText), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('trigger button calls onTriggerPressed callback', (
      WidgetTester tester,
    ) async {
      // Arrange
      bool wasPressed = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapLegend(
              onTriggerPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      // Find and tap the trigger button
      await tester.tap(find.text('Trigger Parking'));
      await tester.pump();

      // Assert
      expect(wasPressed, true);
    });

    testWidgets('end button calls onEndPressed callback', (
      WidgetTester tester,
    ) async {
      // Arrange
      bool wasPressed = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapLegend(
              showEndButton: true,
              onEndPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      // Find and tap the end button
      await tester.tap(find.text('End Parking'));
      await tester.pump();

      // Assert
      expect(wasPressed, true);
    });

    testWidgets('legend items have correct colors', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingMapLegend())),
      );

      // Assert - Check that colored containers exist
      // Find all Container widgets that are children of legend items
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Wrap),
          matching: find.byType(Container),
        ),
      );

      // Verify we have the expected number of containers (legend items + color boxes)
      expect(containers.length, greaterThan(10));
    });

    testWidgets('card has proper styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingMapLegend())),
      );

      // Assert - Find the Card widget
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 4);

      // Check border radius
      final shape = card.shape as RoundedRectangleBorder;
      final borderRadius = shape.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, 12);
    });

    testWidgets('supports scrolling when content overflows', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200, // Constrain height to force scrolling
              child: ParkingMapLegend(),
            ),
          ),
        ),
      );

      // Assert - Verify SingleChildScrollView is present
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('legend item has correct visual properties', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingMapLegend())),
      );

      // Find a specific legend item container (e.g., for "Available" which uses green color)
      final availableItem = find.ancestor(
        of: find.text('Available'),
        matching: find.byType(Container),
      );
      
      // Should find multiple containers (outer container and color box)
      expect(availableItem, findsWidgets);
      
      // Check that color boxes are rendered with correct size
      final colorBoxes = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final decoration = widget.decoration as BoxDecoration?;
          return widget.constraints?.maxWidth == 12 && 
                 widget.constraints?.maxHeight == 12 &&
                 decoration != null;
        }
        return false;
      });
      
      // Should have one color box for each legend item (11 total)
      expect(colorBoxes, findsNWidgets(11));
    });

    testWidgets('corridor item has transparent color with border', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingMapLegend())),
      );

      // Find the corridor item's color box
      final corridorColorBox = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final decoration = widget.decoration as BoxDecoration?;
          return decoration?.color == Colors.transparent &&
                 decoration?.border != null;
        }
        return false;
      });
      
      expect(corridorColorBox, findsOneWidget);
    });
  });
}
