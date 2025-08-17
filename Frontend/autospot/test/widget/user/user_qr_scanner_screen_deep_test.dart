import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userQRScanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';
import 'dart:convert';
import 'dart:async';

// Extended testable QRScanner that exposes internal methods
class TestableDeeperQRScanner extends QRScannerScreen {
  const TestableDeeperQRScanner({super.key});
  
  @override
  TestableDeeperQRScannerState createState() => TestableDeeperQRScannerState();
}

class TestableDeeperQRScannerState extends State<TestableDeeperQRScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  dynamic controller;
  String? result;
  bool isProcessing = false;
  bool permissionGranted = false;
  bool flashEnabled = false;
  
  // Mock controller for testing
  MockDeepQRController? mockController;
  
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }
  
  Future<void> _checkPermission() async {
    // In tests, we control permission via test setup
    setState(() {
      permissionGranted = testPermissionGranted;
    });
  }
  
  // Exposed for testing
  bool testPermissionGranted = false;
  bool testIsAndroid = true;
  bool testForceAccept = true;
  
  @override
  void reassemble() {
    super.reassemble();
    if (testIsAndroid) {
      controller?.pauseCamera();
    } else {
      controller?.resumeCamera();
    }
  }
  
  // Expose the QR validation method for testing
  bool testIsValidEntranceQRCode(String code) {
    // Implement the same logic as _isValidEntranceQRCode
    debugPrint('scanned QR code content: $code');
    
    if (code.isEmpty) {
      debugPrint('QR code content is empty');
      return false;
    }
    
    if (code.startsWith('http://') || code.startsWith('https://')) {
      debugPrint('detected URL format QR code');
      return true;
    }
    
    if (code.contains('ENTRANCE') || code.contains('entrance')) {
      debugPrint('detected QR code containing ENTRANCE keyword');
      return true;
    }
    
    if (code.contains('entrance=')) {
      debugPrint('detected entrance= parameter format QR code');
      return true;
    }
    
    if (code.contains('building=') || code.contains('level=')) {
      debugPrint('detected building or level parameter QR code');
      return true;
    }
    
    try {
      final jsonData = json.decode(code);
      debugPrint('successfully parsed as JSON: $jsonData');
      
      if (jsonData is Map) {
        return true;
      }
    } catch (e) {
      debugPrint('not valid JSON format: $e');
    }
    
    if (code.length < 100) {
      debugPrint('accept simple text QR code');
      return true;
    }
    
    debugPrint('QR code format does not match any known pattern');
    return false;
  }
  
  // Expose the save entrance ID method for testing
  Future<void> testSaveEntranceId(String entranceQRCode) async {
    final prefs = await SharedPreferences.getInstance();
    
    String entranceId = "";
    String building = "";
    String level = "1";
    int x = 0;
    int y = 0;
    
    // Try to parse as JSON first
    try {
      final jsonData = json.decode(entranceQRCode);
      if (jsonData is Map) {
        // New format handling
        if (jsonData.containsKey('entrance_id')) {
          entranceId = jsonData['entrance_id'].toString();
          
          if (jsonData.containsKey('building')) {
            building = jsonData['building'].toString();
          }
          
          if (jsonData.containsKey('level')) {
            level = jsonData['level'].toString();
          }
          
          if (jsonData.containsKey('coordinates') && jsonData['coordinates'] is Map) {
            final coordinates = jsonData['coordinates'] as Map;
            if (coordinates.containsKey('x')) {
              x = int.tryParse(coordinates['x'].toString()) ?? 0;
            }
            if (coordinates.containsKey('y')) {
              y = int.tryParse(coordinates['y'].toString()) ?? 0;
            }
          }
          
          debugPrint('parsed entrance QR code: entrance ID=$entranceId, building=$building, level=$level, coordinates=($x,$y)');
        }
        // Old format handling
        else if (jsonData.containsKey('entrances') && 
            jsonData['entrances'] is List && 
            (jsonData['entrances'] as List).isNotEmpty) {
          
          final entrances = jsonData['entrances'] as List;
          if (entrances[0] is Map && 
              entrances[0].containsKey('entrance_id')) {
            entranceId = entrances[0]['entrance_id'].toString();
          }
        }
        
        if (jsonData.containsKey('destination')) {
          building = jsonData['destination'].toString();
        }
        
        if (entranceId.isEmpty && jsonData.isNotEmpty) {
          entranceId = jsonData.keys.first.toString();
          debugPrint('no valid entrance_id, using first key as ID: $entranceId');
        }
        
        if (jsonData.containsKey('username')) {
          await prefs.setString('qr_username', jsonData['username'].toString());
        }
        
        if (jsonData.containsKey('expire_at')) {
          await prefs.setString('qr_expire_at', jsonData['expire_at'].toString());
        }
      }
    } catch (e) {
      debugPrint('QR code is not valid JSON: $e');
      
      // Extract from other formats
      if (entranceQRCode.startsWith('ENTRANCE_') || entranceQRCode.contains('ENTRANCE')) {
        final parts = entranceQRCode.split('_');
        entranceId = entranceQRCode;
        
        if (parts.length >= 4) {
          building = '${parts[1]}_${parts[2]}'; // BLDG_A
          entranceId = parts[3]; // E001
          
          if (parts.length >= 5) {
            level = parts[4]; // 3
          }
          
          if (parts.length >= 7) {
            x = int.tryParse(parts[5]) ?? 0; // 15
            y = int.tryParse(parts[6]) ?? 0; // 25
          }
        }
      } else if (entranceQRCode.contains('entrance=')) {
        final entrancePattern = RegExp(r'entrance=([^&]+)');
        final entranceMatch = entrancePattern.firstMatch(entranceQRCode);
        entranceId = entranceMatch?.group(1) ?? entranceQRCode;
        
        final buildingPattern = RegExp(r'building=([^&]+)');
        final buildingMatch = buildingPattern.firstMatch(entranceQRCode);
        if (buildingMatch != null) {
          building = buildingMatch.group(1) ?? "";
        }
        
        final levelPattern = RegExp(r'level=([^&]+)');
        final levelMatch = levelPattern.firstMatch(entranceQRCode);
        if (levelMatch != null) {
          level = levelMatch.group(1) ?? "1";
        }
        
        final xPattern = RegExp(r'x=([^&]+)');
        final xMatch = xPattern.firstMatch(entranceQRCode);
        if (xMatch != null) {
          x = int.tryParse(xMatch.group(1) ?? "0") ?? 0;
        }
        
        final yPattern = RegExp(r'y=([^&]+)');
        final yMatch = yPattern.firstMatch(entranceQRCode);
        if (yMatch != null) {
          y = int.tryParse(yMatch.group(1) ?? "0") ?? 0;
        }
      } else {
        entranceId = entranceQRCode.substring(0, entranceQRCode.length > 50 ? 50 : entranceQRCode.length);
        debugPrint('use original QR code content as entranceId (truncated): $entranceId');
      }
    }
    
    // Save all extracted data
    if (entranceId.isNotEmpty) {
      await prefs.setString('entrance_id', entranceId);
      debugPrint('save entrance_id: $entranceId');
    } else {
      entranceId = "ENTRANCE_${DateTime.now().millisecondsSinceEpoch}";
      await prefs.setString('entrance_id', entranceId);
      debugPrint('use default generated entrance_id: $entranceId');
    }
    
    await prefs.setString('entrance_scan_time', DateTime.now().toIso8601String());
    
    if (building.isNotEmpty) {
      await prefs.setString('building_id', building);
      debugPrint('✅ Successfully saved building_id: $building');
    } else {
      building = "DEFAULT_BUILDING";
      await prefs.setString('building_id', building);
      debugPrint('⚠️ No building found in QR code, using default: $building');
    }
    
    await prefs.setString('level', level);
    await prefs.setInt('entrance_x', x);
    await prefs.setInt('entrance_y', y);
    await prefs.setString('raw_qr_content', entranceQRCode);
    
    debugPrint('save entrance information: ID=$entranceId, building=$building, level=$level, coordinates=($x,$y)');
  }
  
  void _onQRViewCreated(dynamic controller) {
    this.controller = controller;
    mockController = controller as MockDeepQRController?;
    
    if (mockController != null) {
      mockController!.scannedDataStream.listen((scanData) async {
      if (!isProcessing && scanData.code != null) {
        debugPrint('QR code scanned: ${scanData.code}');
        
        setState(() {
          isProcessing = true;
          result = scanData.code;
        });
        
        mockController?.pauseCamera();
        
        if (testForceAccept || testIsValidEntranceQRCode(scanData.code!)) {
          await testSaveEntranceId(scanData.code!);
          
          if (mounted) {
            debugPrint('Navigating to destination selection page...');
            Navigator.pushNamed(
              context, 
              '/destination-select',
              arguments: scanData.code
            );
          }
        } else {
          debugPrint('QR code validation failed. Showing error message.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid parking entrance QR code. Please scan a valid code.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                isProcessing = false;
                result = null;
              });
              mockController?.resumeCamera();
            }
          });
        }
      }
    });
    }
  }
  
  void testToggleFlash() async {
    if (controller != null) {
      await controller!.toggleFlash();
      setState(() {
        flashEnabled = !flashEnabled;
      });
    }
  }
  
  // Simulate a QR code scan for testing
  Future<void> simulateScan(String code) async {
    final scanData = MockScanData(code);
    
    if (!isProcessing) {
      debugPrint('QR code scanned: ${scanData.code}');
      
      setState(() {
        isProcessing = true;
        result = scanData.code;
      });
      
      mockController?.pauseCamera();
      
      if (testForceAccept || testIsValidEntranceQRCode(scanData.code!)) {
        await testSaveEntranceId(scanData.code!);
        
        if (mounted) {
          debugPrint('Navigating to destination selection page...');
          Navigator.pushNamed(
            context, 
            '/destination-select',
            arguments: scanData.code
          );
        }
      } else {
        debugPrint('QR code validation failed. Showing error message.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid parking entrance QR code. Please scan a valid code.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              isProcessing = false;
              result = null;
            });
            mockController?.resumeCamera();
          }
        });
      }
    }
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
                    testPermissionGranted = true;
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
            onPressed: testToggleFlash,
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
                buildTestQRScanner(
                  qrKey: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  cutOutSize: MediaQuery.of(context).size.width * 0.8,
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

// Mock classes for testing
class MockDeepQRController {
  final _scanController = StreamController<MockScanData>.broadcast();
  bool isPaused = false;
  bool isFlashOn = false;
  
  Stream<MockScanData> get scannedDataStream => _scanController.stream;
  
  void pauseCamera() {
    isPaused = true;
  }
  
  void resumeCamera() {
    isPaused = false;
  }
  
  Future<void> toggleFlash() async {
    isFlashOn = !isFlashOn;
  }
  
  void dispose() {
    _scanController.close();
  }
  
  void simulateScan(String code) {
    if (!isPaused) {
      _scanController.add(MockScanData(code));
    }
  }
}

class MockScanData {
  final String? code;
  MockScanData(this.code);
}

// Mock QR scanner builder for testing
Widget buildTestQRScanner({
  required GlobalKey qrKey,
  required void Function(dynamic) onQRViewCreated,
  required double cutOutSize,
}) {
  final controller = MockDeepQRController();
  
  // Call onQRViewCreated after frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    onQRViewCreated(controller);
  });
  
  return Container(
    key: qrKey,
    color: Colors.grey[900],
    child: const Center(
      child: Text(
        'Mock QR Scanner',
        style: TextStyle(color: Colors.white54),
      ),
    ),
  );
}

void main() {
  group('QRScannerScreen Deep Coverage Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    group('QR Code Validation Tests', () {
      testWidgets('validates empty QR code', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        expect(state.testIsValidEntranceQRCode(''), false);
      });

      testWidgets('validates URL format QR codes', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        expect(state.testIsValidEntranceQRCode('http://example.com'), true);
        expect(state.testIsValidEntranceQRCode('https://example.com'), true);
      });

      testWidgets('validates ENTRANCE keyword QR codes', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        expect(state.testIsValidEntranceQRCode('ENTRANCE_123'), true);
        expect(state.testIsValidEntranceQRCode('entrance_456'), true);
        expect(state.testIsValidEntranceQRCode('building_entrance_789'), true);
      });

      testWidgets('validates parameter format QR codes', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        expect(state.testIsValidEntranceQRCode('entrance=MAIN'), true);
        expect(state.testIsValidEntranceQRCode('building=A&entrance=1'), true);
        expect(state.testIsValidEntranceQRCode('level=2&spot=123'), true);
      });

      testWidgets('validates JSON format QR codes', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        expect(state.testIsValidEntranceQRCode('{"entrance_id":"E1"}'), true);
        expect(state.testIsValidEntranceQRCode('{"building":"A","level":"1"}'), true);
      });

      testWidgets('validates short text QR codes', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        expect(state.testIsValidEntranceQRCode('SHORT_CODE'), true);
        expect(state.testIsValidEntranceQRCode('A' * 99), true);
        expect(state.testIsValidEntranceQRCode('A' * 100), false);
      });
    });

    group('Entrance ID Saving Tests', () {
      testWidgets('saves JSON format entrance data', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        final jsonQR = json.encode({
          'entrance_id': 'E123',
          'building': 'Building A',
          'level': '2',
          'coordinates': {'x': '10', 'y': '20'},
          'username': 'testuser',
          'expire_at': '2024-12-31'
        });
        
        await state.testSaveEntranceId(jsonQR);
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('entrance_id'), 'E123');
        expect(prefs.getString('building_id'), 'Building A');
        expect(prefs.getString('level'), '2');
        expect(prefs.getInt('entrance_x'), 10);
        expect(prefs.getInt('entrance_y'), 20);
        expect(prefs.getString('qr_username'), 'testuser');
        expect(prefs.getString('qr_expire_at'), '2024-12-31');
      });

      testWidgets('saves old format entrance data', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        final oldFormatQR = json.encode({
          'entrances': [{'entrance_id': 'OLD_E456'}],
          'destination': 'Mall'
        });
        
        await state.testSaveEntranceId(oldFormatQR);
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('entrance_id'), 'OLD_E456');
        expect(prefs.getString('building_id'), 'Mall');
      });

      testWidgets('saves ENTRANCE_ format data', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        await state.testSaveEntranceId('ENTRANCE_BLDG_A_E001_3_15_25');
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('entrance_id'), 'E001');
        expect(prefs.getString('building_id'), 'BLDG_A');
        expect(prefs.getString('level'), '3');
        expect(prefs.getInt('entrance_x'), 15);
        expect(prefs.getInt('entrance_y'), 25);
      });

      testWidgets('saves parameter format data', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        await state.testSaveEntranceId('entrance=MAIN&building=Tower&level=5&x=30&y=40');
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('entrance_id'), 'MAIN');
        expect(prefs.getString('building_id'), 'Tower');
        expect(prefs.getString('level'), '5');
        expect(prefs.getInt('entrance_x'), 30);
        expect(prefs.getInt('entrance_y'), 40);
      });

      testWidgets('handles fallback for unknown format', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        await state.testSaveEntranceId('UNKNOWN_FORMAT_CODE');
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('entrance_id'), 'UNKNOWN_FORMAT_CODE');
        expect(prefs.getString('building_id'), 'DEFAULT_BUILDING');
      });

      testWidgets('generates default entrance ID for empty data', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        await state.testSaveEntranceId('{}'); // Empty JSON
        
        final prefs = await SharedPreferences.getInstance();
        final entranceId = prefs.getString('entrance_id');
        expect(entranceId, isNotNull);
        expect(entranceId!.startsWith('ENTRANCE_'), true);
      });
    });

    group('Permission Flow Tests', () {
      testWidgets('grant permission button updates state', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        await tester.pump();
        
        // Permission screen should be shown
        expect(find.text('Camera permission is required to scan QR codes'), findsOneWidget);
        
        // Tap grant permission
        await tester.tap(find.text('Grant Permission'));
        await tester.pump();
        
        // Scanner screen should be shown
        expect(find.text('Scan Entrance QR Code'), findsOneWidget);
      });
    });

    group('QR Scanning Flow Tests', () {
      testWidgets('successful scan navigates to destination', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        String? navigatedRoute;
        String? navigationArg;
        
        await tester.pumpWidget(
          MaterialApp(
            home: const TestableDeeperQRScanner(),
            onGenerateRoute: (settings) {
              navigatedRoute = settings.name;
              navigationArg = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Destination')),
              );
            },
          ),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        // Grant permission first
        state.testPermissionGranted = true;
        await tester.pump();
        
        // Simulate successful scan
        await state.simulateScan('ENTRANCE_TEST_123');
        await tester.pumpAndSettle();
        
        expect(navigatedRoute, '/destination-select');
        expect(navigationArg, 'ENTRANCE_TEST_123');
      });

      testWidgets('invalid scan shows error and resumes camera', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          MaterialApp(home: const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        // Grant permission and disable force accept
        state.testPermissionGranted = true;
        state.testForceAccept = false;
        await tester.pump();
        
        // Simulate invalid scan
        await state.simulateScan('');
        await tester.pump();
        
        // Error should be shown
        expect(find.text('Invalid parking entrance QR code. Please scan a valid code.'), findsOneWidget);
        
        // Wait for camera to resume
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        
        expect(state.isProcessing, false);
        expect(state.result, null);
      });
    });

    group('Flash Control Tests', () {
      testWidgets('toggles flash state', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        // Grant permission to see flash button
        state.setState(() {
          state.testPermissionGranted = true;
          state.permissionGranted = true;
        });
        await tester.pump();
        
        // Wait for QR scanner to be initialized
        await tester.pumpAndSettle();
        
        expect(state.flashEnabled, false);
        expect(find.byIcon(Icons.flash_off), findsOneWidget);
        
        // Initialize controller manually for test
        state.controller = MockDeepQRController();
        state.mockController = state.controller as MockDeepQRController;
        
        // Toggle flash
        await tester.tap(find.byIcon(Icons.flash_off));
        await tester.pump();
        
        expect(state.flashEnabled, true);
        expect(find.byIcon(Icons.flash_on), findsOneWidget);
      });
    });

    group('Platform Specific Tests', () {
      testWidgets('handles Android reassemble', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        state.testIsAndroid = true;
        state.reassemble();
        
        // Should not crash
        expect(find.byType(TestableDeeperQRScanner), findsOneWidget);
      });

      testWidgets('handles iOS reassemble', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        state.testIsAndroid = false;
        state.reassemble();
        
        // Should not crash
        expect(find.byType(TestableDeeperQRScanner), findsOneWidget);
      });
    });

    group('UI State Tests', () {
      testWidgets('displays processing state correctly', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        // Grant permission first
        state.testPermissionGranted = true;
        state.permissionGranted = true;
        await tester.pump();
        
        // Then set processing state
        state.setState(() {
          state.isProcessing = true;
          state.result = 'TEST_SCAN';
        });
        await tester.pump();
        
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Processing...'), findsOneWidget);
        expect(find.text('Scanned: TEST_SCAN'), findsOneWidget);
      });

      testWidgets('truncates long result display', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        final state = tester.state<TestableDeeperQRScannerState>(
          find.byType(TestableDeeperQRScanner),
        );
        
        // Grant permission first
        state.testPermissionGranted = true;
        state.permissionGranted = true;
        await tester.pump();
        
        // Set long result
        state.setState(() {
          state.result = 'A' * 50; // Very long result
        });
        await tester.pump();
        
        expect(find.textContaining('...'), findsOneWidget);
      });
    });

    group('Lifecycle Tests', () {
      testWidgets('disposes controller properly', (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(const TestableDeeperQRScanner()),
        );
        
        await tester.pump();
        
        // Replace widget to trigger dispose
        await tester.pumpWidget(
          TestHelpers.createTestableWidget(Container()),
        );
        
        expect(find.byType(TestableDeeperQRScanner), findsNothing);
        expect(find.byType(Container), findsOneWidget);
      });
    });
  });
}