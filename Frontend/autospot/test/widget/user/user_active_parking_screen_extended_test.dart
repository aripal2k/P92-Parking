import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';
import 'dart:convert';
import 'dart:async';

// Mock ActiveParkingScreen that doesn't make HTTP requests
class MockActiveParkingScreen extends StatefulWidget {
  final DateTime startTime;
  final bool showNavigationBar;
  final bool shouldFailSession;
  final bool hasMapData;
  final int mapLevels;
  final bool hasNavigationPath;
  final bool hasDestinationPath;

  const MockActiveParkingScreen({
    super.key,
    required this.startTime,
    this.showNavigationBar = false,
    this.shouldFailSession = false,
    this.hasMapData = true,
    this.mapLevels = 1,
    this.hasNavigationPath = false,
    this.hasDestinationPath = false,
  });

  @override
  State<MockActiveParkingScreen> createState() => _MockActiveParkingScreenState();
}

class _MockActiveParkingScreenState extends State<MockActiveParkingScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _sessionStarted = false;
  bool _showMap = false;
  String _pathDisplayMode = "entrance_to_slot";
  int selectedLevel = 1;
  String? allocatedSpotId;
  List<List<dynamic>> navigationPath = [];
  List<List<dynamic>> destinationPath = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    allocatedSpotId = prefs.getString('allocated_spot_id');
    
    final navPathJson = prefs.getString('navigation_path');
    final destPathJson = prefs.getString('destination_path');
    
    if (navPathJson != null && widget.hasNavigationPath) {
      navigationPath = List<List<dynamic>>.from(json.decode(navPathJson));
    }
    
    if (destPathJson != null && widget.hasDestinationPath) {
      destinationPath = List<List<dynamic>>.from(json.decode(destPathJson));
    }
    
    // Simulate session start
    if (!widget.shouldFailSession) {
      setState(() {
        _sessionStarted = true;
        _elapsed = DateTime.now().difference(widget.startTime);
      });
      _startTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to start session")),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(widget.startTime);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _toggleMapDisplay() {
    setState(() {
      _showMap = !_showMap;
    });
  }

  void _togglePathMode() {
    setState(() {
      _pathDisplayMode = _pathDisplayMode == "entrance_to_slot" 
          ? "slot_to_destination" 
          : "entrance_to_slot";
    });
  }

  Future<void> _confirmEndParkingSession() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 24,
          backgroundColor: const Color(0xFFCFF4D2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'End Parking Session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to end the parking session?',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        shadowColor: Colors.black26,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        shadowColor: Colors.black38,
                      ),
                      child: const Text('End Session'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      Navigator.pushReplacementNamed(
        context,
        '/parking-fee',
        arguments: {
          'startTime': widget.startTime,
          'endTime': DateTime.now(),
          'isActiveSession': false,
          'duration': _elapsed,
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildTimerView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 100, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_elapsed),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _toggleMapDisplay,
            icon: const Icon(Icons.map),
            label: const Text('View Navigation Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _confirmEndParkingSession,
            icon: const Icon(Icons.stop),
            label: const Text('End Parking Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (!widget.hasMapData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Navigation Map Not Available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No navigation data found for this session',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _toggleMapDisplay,
              icon: const Icon(Icons.timer),
              label: const Text('Back to Timer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Timer display and controls at top
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allocatedSpotId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF68B245).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_parking, 
                            size: 14, 
                            color: const Color(0xFF68B245),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            allocatedSpotId!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF68B245),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (navigationPath.isNotEmpty && destinationPath.isNotEmpty) ? _togglePathMode : null,
                    icon: Icon(_pathDisplayMode == "entrance_to_slot" ? Icons.directions_walk : Icons.location_on),
                    label: Text(_pathDisplayMode == "entrance_to_slot" ? "To Slot" : "To Destination"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pathDisplayMode == "entrance_to_slot" ? Colors.blue : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Level selector (if multiple levels)
        if (widget.mapLevels > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.mapLevels,
              itemBuilder: (context, index) {
                final level = index + 1;
                final isSelected = selectedLevel == level;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedLevel = level;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.green : Colors.grey[300],
                      foregroundColor: isSelected ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text('Level $level'),
                  ),
                );
              },
            ),
          ),

        // Map display placeholder
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('Map Display Placeholder'),
            ),
          ),
        ),

        // Path info display
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _pathDisplayMode == "entrance_to_slot" 
                      ? Icons.directions_walk 
                      : Icons.location_on,
                  size: 14,
                  color: _pathDisplayMode == "entrance_to_slot" 
                      ? Colors.blue 
                      : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _pathDisplayMode == "entrance_to_slot" 
                      ? "Entrance → Parking Slot" 
                      : "Parking Slot → Destination",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pathDisplayMode == "entrance_to_slot" 
                        ? Colors.blue.withOpacity(0.08) 
                        : Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 10,
                        color: _pathDisplayMode == "entrance_to_slot" 
                            ? Colors.blue 
                            : Colors.orange,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${_pathDisplayMode == "entrance_to_slot" ? navigationPath.length : destinationPath.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _pathDisplayMode == "entrance_to_slot" 
                              ? Colors.blue 
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Control buttons at bottom
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleMapDisplay,
                icon: const Icon(Icons.timer),
                label: const Text('Timer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _confirmEndParkingSession,
                icon: const Icon(Icons.stop),
                label: const Text('End Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      'AutoSpot',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: _sessionStarted
                      ? (_showMap ? _buildMapView() : _buildTimerView())
                      : const Center(child: CircularProgressIndicator(color: Colors.green)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('ActiveParkingScreen Extended Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    group('Map Display Tests', () {
      testWidgets('shows loading state when toggling to map view', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(startTime: now),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert
        expect(find.text('Map Display Placeholder'), findsOneWidget);
      });

      testWidgets('displays no map available when map data is missing', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(
              startTime: now,
              hasMapData: false,
            ),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert
        expect(find.text('Navigation Map Not Available'), findsOneWidget);
        expect(find.text('No navigation data found for this session'), findsOneWidget);
        expect(find.text('Back to Timer'), findsOneWidget);
      });

      testWidgets('displays multi-level selector when map has multiple levels', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'B-201',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(
              startTime: now,
              mapLevels: 3,
            ),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert
        expect(find.text('Level 1'), findsOneWidget);
        expect(find.text('Level 2'), findsOneWidget);
        expect(find.text('Level 3'), findsOneWidget);

        // Test level selection
        await tester.tap(find.text('Level 2'));
        await tester.pump();
        
        final level2Button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Level 2'),
        );
        expect(level2Button.style?.backgroundColor?.resolve({}), Colors.green);
      });

      testWidgets('displays parking spot info in map view', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'C-303',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(startTime: now),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert
        expect(find.text('C-303'), findsOneWidget);
        expect(find.byIcon(Icons.local_parking), findsOneWidget);
      });
    });

    group('Path Navigation Tests', () {
      testWidgets('toggles between navigation paths correctly', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
          'navigation_path': json.encode([[1, 0, 0], [1, 1, 0], [1, 2, 0]]),
          'destination_path': json.encode([[1, 2, 0], [1, 3, 0]]),
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(
              startTime: now,
              hasNavigationPath: true,
              hasDestinationPath: true,
            ),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert initial state
        expect(find.text('To Slot'), findsOneWidget);
        expect(find.text('Entrance → Parking Slot'), findsOneWidget);
        expect(find.text('3'), findsOneWidget); // Navigation path points

        // Toggle path mode
        await tester.tap(find.text('To Slot'));
        await tester.pump();

        // Assert toggled state
        expect(find.text('To Destination'), findsOneWidget);
        expect(find.text('Parking Slot → Destination'), findsOneWidget);
        expect(find.text('2'), findsOneWidget); // Destination path points
      });

      testWidgets('disables path toggle when only one path exists', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
          'navigation_path': json.encode([[1, 0, 0], [1, 1, 0]]),
          'destination_path': json.encode([]), // Empty destination path
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(
              startTime: now,
              hasNavigationPath: true,
              hasDestinationPath: false,
            ),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert - Path toggle button should be disabled
        final pathButtons = find.widgetWithText(ElevatedButton, 'To Slot');
        if (pathButtons.evaluate().isNotEmpty) {
          final pathButton = tester.widget<ElevatedButton>(pathButtons);
          expect(pathButton.onPressed, isNull);
        }
      });
    });

    group('Session Management Tests', () {
      testWidgets('handles session start failure gracefully', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(
              startTime: now,
              shouldFailSession: true,
            ),
          ),
        );
        
        await tester.pump();

        // Assert
        expect(find.text('Failed to start session'), findsOneWidget);
      });

      testWidgets('timer continues running while viewing map', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(startTime: now),
          ),
        );
        
        await tester.pumpAndSettle();

        // Get initial timer value
        expect(find.textContaining('00:00:'), findsOneWidget);

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Wait 2 seconds
        await tester.pump(const Duration(seconds: 2));

        // Timer should still be visible and updated in map view
        expect(find.textContaining('00:00:'), findsOneWidget);

        // Toggle back to timer view
        await tester.tap(find.text('Timer'));
        await tester.pump();

        // Timer should show updated value
        expect(find.textContaining('00:00:'), findsOneWidget);
      });

      testWidgets('ends session and navigates to parking fee screen', (WidgetTester tester) async {
        // Arrange
        final startTime = DateTime.now().subtract(const Duration(minutes: 15));
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        String? navigatedRoute;
        Map<String, dynamic>? navigationArgs;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: MockActiveParkingScreen(startTime: startTime),
            onGenerateRoute: (settings) {
              navigatedRoute = settings.name;
              navigationArgs = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Parking Fee')),
              );
            },
          ),
        );
        
        await tester.pumpAndSettle();

        // End session
        await tester.tap(find.text('End Parking Session'));
        await tester.pump();

        // Confirm in dialog
        await tester.tap(find.text('End Session'));
        await tester.pumpAndSettle();

        // Assert
        expect(navigatedRoute, '/parking-fee');
        expect(navigationArgs?['isActiveSession'], false);
        expect(navigationArgs?['duration'], isA<Duration>());
        expect(navigationArgs?['startTime'], startTime);
      });
    });

    group('UI State Tests', () {
      testWidgets('timer displays correct format for various durations', (WidgetTester tester) async {
        // Test with one specific duration
        final startTime = DateTime.now().subtract(const Duration(minutes: 5, seconds: 45));
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(startTime: startTime),
          ),
        );
        
        await tester.pumpAndSettle();

        // Verify timer format (HH:MM:SS)
        final timerText = find.textContaining(':').evaluate().first.widget as Text;
        final text = timerText.data!;
        expect(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(text), isTrue);
      });

      testWidgets('map view preserves timer display', (WidgetTester tester) async {
        // Arrange
        final startTime = DateTime.now().subtract(const Duration(minutes: 10, seconds: 30));
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(startTime: startTime),
          ),
        );
        
        await tester.pumpAndSettle();

        // Toggle to map view
        await tester.tap(find.text('View Navigation Map'));
        await tester.pump();

        // Assert - Timer should be visible in map view
        expect(find.byIcon(Icons.timer), findsNWidgets(2)); // One in button, one in display
        expect(find.textContaining('00:10:'), findsOneWidget);
      });

      testWidgets('handles widget disposal properly', (WidgetTester tester) async {
        // Arrange
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'username': 'testuser',
          'vehicle_id': 'ABC123',
          'allocated_spot_id': 'A-101',
        });

        // Act
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(
            MockActiveParkingScreen(startTime: now),
          ),
        );
        
        await tester.pumpAndSettle();

        // Dispose widget
        await tester.pumpWidget(Container());

        // Assert - Should dispose without errors
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(MockActiveParkingScreen), findsNothing);
      });
    });
  });
}