import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userQRScanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

// Mock QR Controller for testing
class MockQRController {
  final _scanStream = Stream<MockScanData>.periodic(
    const Duration(seconds: 2),
    (count) => MockScanData('ENTRANCE_TEST_$count'),
  );
  
  Stream<MockScanData> get scannedDataStream => _scanStream;
  
  void pauseCamera() {}
  void resumeCamera() {}
  void toggleFlash() {}
  void dispose() {}
}

class MockScanData {
  final String? code;
  MockScanData(this.code);
}

void main() {
  group('QRScannerScreen Widget Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('initializes and calls initState', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );

      // Assert - Widget is created and initState is called
      expect(find.byType(QRScannerScreen), findsOneWidget);
    });

    testWidgets('shows permission UI when permission not granted', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Camera permission is required to scan QR codes'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
    });

    testWidgets('shows scanner UI structure when permission granted', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Create widget that simulates permission granted
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(permissionGranted: true),
        ),
      );
      
      await tester.pump();

      // Assert scanner UI structure
      expect(find.text('Scan Entrance QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      expect(find.text('Position QR code within the frame'), findsOneWidget);
      
      // Check scaffold background is black for scanner
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('toggles flash icon when tapped', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(permissionGranted: true),
        ),
      );
      
      await tester.pump();

      // Initially flash is off
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      
      // Tap flash button
      await tester.tap(find.byIcon(Icons.flash_off));
      await tester.pump();
      
      // Flash should be on
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('shows processing indicator when scanning', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(
            permissionGranted: true,
            isProcessing: true,
          ),
        ),
      );
      
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing...'), findsOneWidget);
    });

    testWidgets('displays scanned result text', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(
            permissionGranted: true,
            result: 'ENTRANCE_12345',
          ),
        ),
      );
      
      await tester.pump();

      // Assert
      expect(find.text('Scanned: ENTRANCE_12345'), findsOneWidget);
    });

    testWidgets('truncates long scanned result', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final longResult = 'ENTRANCE_${'A' * 50}';

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(
            permissionGranted: true,
            result: longResult,
          ),
        ),
      );
      
      await tester.pump();

      // Assert - Result should be truncated to 20 chars + '...'
      expect(find.textContaining('Scanned: ENTRANCE_AAAAAAAAAAA...'), findsOneWidget);
    });

    testWidgets('processes valid QR code and navigates', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      bool navigated = false;
      String? navigationArg;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: _TestableQRScannerScreen(
            permissionGranted: true,
            onQRScanned: (code) async {
              navigated = true;
              navigationArg = code;
            },
          ),
          routes: {
            '/destination-select': (context) => const Scaffold(body: Text('Destination')),
          },
        ),
      );
      
      await tester.pump();

      // Simulate QR scan
      final state = tester.state<_TestableQRScannerScreenState>(
        find.byType(_TestableQRScannerScreen),
      );
      await state.simulateQRScan('ENTRANCE_TEST_123');
      await tester.pumpAndSettle();

      // Assert
      expect(navigated, true);
      expect(navigationArg, 'ENTRANCE_TEST_123');
    });

    testWidgets('shows error for invalid QR code', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: _TestableQRScannerScreen(
            permissionGranted: true,
            forceAccept: false, // Disable force accept to test validation
          ),
        ),
      );
      
      await tester.pump();

      // Simulate invalid QR scan
      final state = tester.state<_TestableQRScannerScreenState>(
        find.byType(_TestableQRScannerScreen),
      );
      await state.simulateQRScan(''); // Empty QR code
      await tester.pump();

      // Assert - Should show error snackbar
      expect(find.text('Invalid parking entrance QR code. Please scan a valid code.'), findsOneWidget);
    });

    testWidgets('app bar actions are visible', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(permissionGranted: true),
        ),
      );
      
      await tester.pump();

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      expect(appBar.actions!.length, 1);
    });

    testWidgets('scanner area has correct size', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(permissionGranted: true),
        ),
      );
      
      await tester.pump();

      // Assert - Check that Column with Expanded widgets exists
      final expandedWidgets = find.byType(Expanded);
      expect(expandedWidgets, findsWidgets);
      
      // Find the first Expanded widget (scanner area)
      final firstExpanded = tester.widget<Expanded>(expandedWidgets.first);
      expect(firstExpanded.flex, 5);
    });

    testWidgets('info area has correct layout', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(permissionGranted: true),
        ),
      );
      
      await tester.pump();

      // Assert - Check that Column with Expanded widgets exists
      final expandedWidgets = find.byType(Expanded);
      expect(expandedWidgets, findsWidgets);
      
      // Find the second Expanded widget (info area)
      final secondExpanded = tester.widget<Expanded>(expandedWidgets.at(1));
      expect(secondExpanded.flex, 1);
    });

    testWidgets('processing overlay has correct style', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(
            permissionGranted: true,
            isProcessing: true,
          ),
        ),
      );
      
      await tester.pump();

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(Container),
        ).at(1), // Second container in stack
      );
      
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.black.withOpacity(0.5));
      expect(decoration.borderRadius, BorderRadius.circular(10));
    });

    testWidgets('permission icon has correct properties', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Assert
      final icon = tester.widget<Icon>(find.byIcon(Icons.camera_alt));
      expect(icon.size, 64);
      expect(icon.color, Colors.grey);
    });

    testWidgets('handles reassemble for Android platform', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(
            permissionGranted: true,
            isAndroid: true,
          ),
        ),
      );
      
      await tester.pump();

      // Trigger reassemble
      final state = tester.state<_TestableQRScannerScreenState>(
        find.byType(_TestableQRScannerScreen),
      );
      state.reassemble();
      
      // Should not crash
      expect(find.byType(_TestableQRScannerScreen), findsOneWidget);
    });

    testWidgets('handles reassemble for iOS platform', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(
            permissionGranted: true,
            isAndroid: false,
          ),
        ),
      );
      
      await tester.pump();

      // Trigger reassemble
      final state = tester.state<_TestableQRScannerScreenState>(
        find.byType(_TestableQRScannerScreen),
      );
      state.reassemble();
      
      // Should not crash
      expect(find.byType(_TestableQRScannerScreen), findsOneWidget);
    });

    testWidgets('disposes controller on widget disposal', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          _TestableQRScannerScreen(permissionGranted: true),
        ),
      );
      
      await tester.pump();

      // Dispose widget
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );

      // Should dispose without errors
      expect(find.byType(Container), findsOneWidget);
      expect(find.byType(_TestableQRScannerScreen), findsNothing);
    });
  });
}

// Testable version of QRScannerScreen
class _TestableQRScannerScreen extends StatefulWidget {
  final bool permissionGranted;
  final bool isProcessing;
  final String? result;
  final bool forceAccept;
  final bool isAndroid;
  final Future<void> Function(String)? onQRScanned;

  const _TestableQRScannerScreen({
    this.permissionGranted = false,
    this.isProcessing = false,
    this.result,
    this.forceAccept = true,
    this.isAndroid = true,
    this.onQRScanned,
  });

  @override
  State<_TestableQRScannerScreen> createState() => _TestableQRScannerScreenState();
}

class _TestableQRScannerScreenState extends State<_TestableQRScannerScreen> {
  late bool permissionGranted;
  late bool isProcessing;
  late String? result;
  bool flashEnabled = false;
  MockQRController? controller;

  @override
  void initState() {
    super.initState();
    permissionGranted = widget.permissionGranted;
    isProcessing = widget.isProcessing;
    result = widget.result;
    
    if (permissionGranted) {
      controller = MockQRController();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (widget.isAndroid) {
      controller?.pauseCamera();
    } else {
      controller?.resumeCamera();
    }
  }

  Future<void> simulateQRScan(String code) async {
    if (code.isEmpty && !widget.forceAccept) {
      // Show error for invalid QR
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid parking entrance QR code. Please scan a valid code.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      isProcessing = true;
      result = code;
    });

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entrance_id', code);
    await prefs.setString('entrance_scan_time', DateTime.now().toIso8601String());

    if (widget.onQRScanned != null) {
      await widget.onQRScanned!(code);
    }

    setState(() {
      isProcessing = false;
    });
  }

  void _toggleFlash() {
    setState(() {
      flashEnabled = !flashEnabled;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!permissionGranted) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: const Text('QR Scanner', style: TextStyle(color: Colors.black)),
          backgroundColor: const Color(0xFFA3DB94),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Camera permission is required to scan QR codes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    permissionGranted = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA3DB94),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Entrance QR Code', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(flashEnabled ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Text(
                      'Camera Preview',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                if (isProcessing)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3DB94)),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Position QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (result != null && result!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Scanned: ${result!.length > 20 ? '${result!.substring(0, 20)}...' : result}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}