import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';
import 'package:autospot/models/parking_map.dart';

void main() {
  group('ParkingMapWidget Tests', () {
    late ParkingMap basicMap;
    late ParkingMap complexMap;

    setUp(() {
      // Create a basic test map
      basicMap = ParkingMap(
        building: 'Test Building',
        level: 1,
        rows: 4,
        cols: 4,
        entrances: [
          {'x': 0, 'y': 0, 'type': 'car'},
          {'x': 3, 'y': 3, 'type': 'pedestrian'},
        ],
        exits: [
          {'x': 3, 'y': 0},
        ],
        slots: [
          {'x': 1, 'y': 1, 'status': 'available', 'slot_id': 'A01'},
          {'x': 2, 'y': 1, 'status': 'occupied', 'slot_id': 'A02'},
          {'x': 1, 'y': 2, 'status': 'allocated', 'slot_id': 'A03'},
        ],
        corridors: [
          {
            'points': [[0, 1], [1, 1], [2, 1], [3, 1]],
            'direction': 'forward',
            'is_path': false,
          },
        ],
        walls: [
          {
            'points': [[0, 3], [3, 3]],
          },
        ],
        ramps: [
          {'x': 2, 'y': 2},
        ],
      );

      // Create a complex map with navigation paths
      complexMap = ParkingMap(
        building: 'Complex Building',
        level: 2,
        rows: 5,
        cols: 5,
        entrances: [
          {'x': 0, 'y': 0, 'type': 'car'},
        ],
        exits: [
          {'x': 4, 'y': 4},
        ],
        slots: [
          {'x': 2, 'y': 2, 'status': 'available', 'slot_id': 'B01'},
          {'x': 3, 'y': 2, 'status': 'allocated', 'slot_id': 'B02'},
        ],
        corridors: [
          // Regular corridor
          {
            'points': [[0, 2], [1, 2], [2, 2], [3, 2], [4, 2]],
            'direction': 'forward',
            'is_path': false,
          },
          // Navigation path with markers
          {
            'points': [[1, 1]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'path_type': 'entry',
            'arrow_dx': 1,
            'arrow_dy': 0,
          },
          {
            'points': [[2, 2]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'is_destination': true,
            'path_type': 'entry',
          },
        ],
        walls: [],
        ramps: [],
      );
    });

    testWidgets('renders basic map structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should render a 4x4 grid (16 cells)
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
      
      // Check for aspect ratio
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('displays entrance colors correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Find containers with orange color (car entrance)
      final orangeContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.orange,
      );
      expect(orangeContainers, findsOneWidget);

      // Find containers with purple color (pedestrian entrance)
      final purpleContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.purple,
      );
      expect(purpleContainers, findsOneWidget);
    });

    testWidgets('displays exit colors correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Find containers with brown color (exit)
      final brownContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.brown,
      );
      expect(brownContainers, findsOneWidget);
    });

    testWidgets('displays parking slot colors correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Find green containers (available slots)
      final greenContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.green,
      );
      expect(greenContainers, findsOneWidget);

      // Find red containers (occupied slots)
      final redContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.red,
      );
      expect(redContainers, findsNWidgets(2)); // 1 occupied + 1 allocated (shown as red for non-operator)
    });

    testWidgets('displays allocated slot as yellow for operator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: true,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Find yellow containers (allocated slots for operator)
      final yellowContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.yellow,
      );
      expect(yellowContainers, findsOneWidget);
    });

    testWidgets('displays allocated slot as yellow for user when selected', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: 1,
              selectedY: 2,
              selectedLevel: 1,
              allocatedSpotId: 'A03',
            ),
          ),
        ),
      );

      // Find yellow containers (user's allocated slot)
      final yellowContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.yellow,
      );
      expect(yellowContainers, findsOneWidget);
    });

    testWidgets('displays ramps correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Find pink containers (ramps)
      final pinkContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.pinkAccent,
      );
      expect(pinkContainers, findsOneWidget);
    });

    testWidgets('displays walls correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Find grey containers (walls)
      final greyContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.grey,
      );
      expect(greyContainers, findsWidgets);
    });

    testWidgets('displays corridor arrows correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should have arrow icons for corridors
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('handles tap on available slot', (WidgetTester tester) async {
      int? tappedX;
      int? tappedY;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
              onTapCell: (x, y) {
                tappedX = x;
                tappedY = y;
              },
            ),
          ),
        ),
      );

      // Find and tap a green (available) slot
      final greenSlot = find.byWidgetPredicate(
        (widget) => widget is GestureDetector &&
                   widget.child is Container &&
                   (widget.child as Container).decoration is BoxDecoration &&
                   ((widget.child as Container).decoration as BoxDecoration).color == Colors.green,
      );
      
      await tester.tap(greenSlot);
      await tester.pump();

      expect(tappedX, 1);
      expect(tappedY, 1);
    });

    testWidgets('shows selection border on selected slot', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: false,
              selectedX: 1,
              selectedY: 1,
              selectedLevel: 1,
            ),
          ),
        ),
      );

      // Find container with black border
      final selectedContainer = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).border != null &&
                   (widget.decoration as BoxDecoration).border!.top.color == const Color.fromARGB(255, 0, 0, 0),
      );
      expect(selectedContainer, findsOneWidget);
    });

    testWidgets('displays navigation path markers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: complexMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should have arrow icons for navigation markers
      expect(find.byIcon(Icons.arrow_forward), findsWidgets);
      
      // Should have location pin for destination
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('getDirectionArrow returns correct icons for forward mode', (WidgetTester tester) async {
      final widget = ParkingMapWidget(
        map: basicMap,
        isOperator: false,
        preview: false,
        selectedX: null,
        selectedY: null,
        selectedLevel: null,
      );

      expect(widget.getDirectionArrow(1, 0, 'forward'), Icons.arrow_forward);
      expect(widget.getDirectionArrow(-1, 0, 'forward'), Icons.arrow_back);
      expect(widget.getDirectionArrow(0, 1, 'forward'), Icons.arrow_upward);
      expect(widget.getDirectionArrow(0, -1, 'forward'), Icons.arrow_downward);
      expect(widget.getDirectionArrow(0, 0, 'forward'), Icons.circle);
    });

    testWidgets('getDirectionArrow returns correct icons for backward mode', (WidgetTester tester) async {
      final widget = ParkingMapWidget(
        map: basicMap,
        isOperator: false,
        preview: false,
        selectedX: null,
        selectedY: null,
        selectedLevel: null,
      );

      expect(widget.getDirectionArrow(1, 0, 'backward'), Icons.arrow_back);
      expect(widget.getDirectionArrow(-1, 0, 'backward'), Icons.arrow_forward);
      expect(widget.getDirectionArrow(0, 1, 'backward'), Icons.arrow_downward);
      expect(widget.getDirectionArrow(0, -1, 'backward'), Icons.arrow_upward);
    });

    testWidgets('getDirectionArrow returns compare_arrows for both mode', (WidgetTester tester) async {
      final widget = ParkingMapWidget(
        map: basicMap,
        isOperator: false,
        preview: false,
        selectedX: null,
        selectedY: null,
        selectedLevel: null,
      );

      expect(widget.getDirectionArrow(1, 0, 'both'), Icons.compare_arrows);
      expect(widget.getDirectionArrow(0, 1, 'both'), Icons.compare_arrows);
    });

    testWidgets('getLinePoints calculates correct line points', (WidgetTester tester) async {
      final widget = ParkingMapWidget(
        map: basicMap,
        isOperator: false,
        preview: false,
        selectedX: null,
        selectedY: null,
        selectedLevel: null,
      );

      // Test horizontal line
      final horizontalPoints = widget.getLinePoints(0, 0, 3, 0);
      expect(horizontalPoints.length, 4);
      expect(horizontalPoints[0], [0, 0]);
      expect(horizontalPoints[3], [3, 0]);

      // Test vertical line
      final verticalPoints = widget.getLinePoints(0, 0, 0, 3);
      expect(verticalPoints.length, 4);
      expect(verticalPoints[0], [0, 0]);
      expect(verticalPoints[3], [0, 3]);

      // Test diagonal line
      final diagonalPoints = widget.getLinePoints(0, 0, 2, 2);
      // Verify start and end points are included
      expect(diagonalPoints.first, [0, 0]);
      expect(diagonalPoints.last, [2, 2]);
      // The diagonal should have intermediate points
      expect(diagonalPoints.length, greaterThan(2));
    });

    testWidgets('handles special navigation override cases', (WidgetTester tester) async {
      final specialMap = ParkingMap(
        building: 'Special Building',
        level: 1,
        rows: 3,
        cols: 3,
        entrances: [],
        exits: [],
        slots: [],
        corridors: [
          {
            'points': [[1, 1]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'arrow_dx': 1,
            'arrow_dy': 0,
            'special_override': 'up_arrow',
          },
        ],
        walls: [],
        ramps: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: specialMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should display up arrow despite dx/dy values
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('handles custom arrow icon codes', (WidgetTester tester) async {
      final customMap = ParkingMap(
        building: 'Custom Building',
        level: 1,
        rows: 3,
        cols: 3,
        entrances: [],
        exits: [],
        slots: [],
        corridors: [
          {
            'points': [[1, 1]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'arrow_dx': 0,
            'arrow_dy': 0,
            'custom_arrow_icon': 0xe838, // star icon code
          },
        ],
        walls: [],
        ramps: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: customMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should display star icon
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('respects visibility flag for markers', (WidgetTester tester) async {
      final visibilityMap = ParkingMap(
        building: 'Visibility Building',
        level: 1,
        rows: 3,
        cols: 3,
        entrances: [],
        exits: [],
        slots: [],
        corridors: [
          {
            'points': [[1, 1]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'visible': false,
            'arrow_dx': 1,
            'arrow_dy': 0,
          },
        ],
        walls: [],
        ramps: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: visibilityMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should not display arrow for invisible marker
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('handles bidirectional corridors with rotation', (WidgetTester tester) async {
      final bidirectionalMap = ParkingMap(
        building: 'Bidirectional Building',
        level: 1,
        rows: 3,
        cols: 3,
        entrances: [],
        exits: [],
        slots: [],
        corridors: [
          {
            'points': [[0, 1], [1, 1], [2, 1]],
            'direction': 'both',
          },
        ],
        walls: [],
        ramps: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: bidirectionalMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should display compare_arrows icons
      expect(find.byIcon(Icons.compare_arrows), findsWidgets);
    });

    testWidgets('preview mode affects rendering', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: basicMap,
              isOperator: false,
              preview: true,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should still render the map in preview mode
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('handles exit path type correctly', (WidgetTester tester) async {
      final exitPathMap = ParkingMap(
        building: 'Exit Path Building',
        level: 1,
        rows: 3,
        cols: 3,
        entrances: [],
        exits: [],
        slots: [],
        corridors: [
          {
            'points': [[1, 1]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'path_type': 'exit',
            'arrow_dx': 1,
            'arrow_dy': 0,
          },
        ],
        walls: [],
        ramps: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: exitPathMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should display light blue color for exit path
      final lightBlueContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.lightBlueAccent,
      );
      expect(lightBlueContainers, findsOneWidget);
    });

    testWidgets('handles destination marker on ramp', (WidgetTester tester) async {
      final rampDestinationMap = ParkingMap(
        building: 'Ramp Destination Building',
        level: 1,
        rows: 3,
        cols: 3,
        entrances: [],
        exits: [],
        slots: [],
        corridors: [
          {
            'points': [[1, 1]],
            'direction': 'forward',
            'is_path': true,
            'is_marker': true,
            'is_destination': true,
            'path_type': 'entry',
          },
        ],
        walls: [],
        ramps: [
          {'x': 1, 'y': 1},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParkingMapWidget(
              map: rampDestinationMap,
              isOperator: false,
              preview: false,
              selectedX: null,
              selectedY: null,
              selectedLevel: null,
            ),
          ),
        ),
      );

      // Should display location pin on pink ramp
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      final pinkContainers = find.byWidgetPredicate(
        (widget) => widget is Container &&
                   widget.decoration is BoxDecoration &&
                   (widget.decoration as BoxDecoration).color == Colors.pinkAccent,
      );
      expect(pinkContainers, findsOneWidget);
    });
  });
}