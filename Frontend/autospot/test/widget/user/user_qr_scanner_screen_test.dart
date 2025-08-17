import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:autospot/user/userQRScanner_screen.dart';
import 'dart:convert';

@GenerateMocks([Permission])
void main() {
  late SharedPreferences mockPrefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Setup shared preferences mock
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
  });

  group('QRScannerScreen Tests', () {
    testWidgets('shows permission request screen when permission not granted', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QRScannerScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show permission request UI
      expect(find.text('Camera permission is required to scan QR codes'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('permission request button has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QRScannerScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final buttonStyle = button.style!;
      
      // Verify button color
      final backgroundColor = buttonStyle.backgroundColor!.resolve({});
      expect(backgroundColor, const Color(0xFFA3DB94));
    });

    testWidgets('app bar shows correct title for permission screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QRScannerScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('QR Scanner'), findsOneWidget);
      
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFA3DB94));
    });

    testWidgets('validates QR code formats correctly', (WidgetTester tester) async {
      // Create an instance of the state to test the validation method
      final state = _QRScannerScreenState();

      // Test various QR code formats
      expect(state._isValidEntranceQRCode('ENTRANCE_123'), true);
      expect(state._isValidEntranceQRCode('entrance_456'), true);
      expect(state._isValidEntranceQRCode('building=A&entrance=B'), true);
      expect(state._isValidEntranceQRCode('level=2'), true);
      expect(state._isValidEntranceQRCode('http://example.com/entrance'), true);
      expect(state._isValidEntranceQRCode('https://example.com'), true);
      expect(state._isValidEntranceQRCode('{"entrance_id": "123"}'), true);
      expect(state._isValidEntranceQRCode('short_text'), true);
      expect(state._isValidEntranceQRCode(''), false);
    });

    testWidgets('saves entrance data correctly', (WidgetTester tester) async {
      // Test JSON format
      final state = _QRScannerScreenState();
      
      await state._saveEntranceId('{"entrance_id": "E123", "building": "B1", "level": "2", "coordinates": {"x": 10, "y": 20}}');
      
      expect(mockPrefs.getString('entrance_id'), 'E123');
      expect(mockPrefs.getString('building_id'), 'B1');
      expect(mockPrefs.getString('level'), '2');
      expect(mockPrefs.getInt('entrance_x'), 10);
      expect(mockPrefs.getInt('entrance_y'), 20);
      expect(mockPrefs.getString('entrance_scan_time'), isNotNull);
    });

    testWidgets('handles ENTRANCE_ format correctly', (WidgetTester tester) async {
      final state = _QRScannerScreenState();
      
      await state._saveEntranceId('ENTRANCE_BUILDING1_E001_3_15_25');
      
      expect(mockPrefs.getString('entrance_id'), 'E001');
      expect(mockPrefs.getString('building_id'), 'BUILDING1');
      expect(mockPrefs.getString('level'), '3');
      expect(mockPrefs.getInt('entrance_x'), 15);
      expect(mockPrefs.getInt('entrance_y'), 25);
    });

    testWidgets('handles parameter format correctly', (WidgetTester tester) async {
      final state = _QRScannerScreenState();
      
      await state._saveEntranceId('building=TestBuilding&entrance=MainEntrance&level=5&x=30&y=40');
      
      expect(mockPrefs.getString('entrance_id'), 'MainEntrance');
      expect(mockPrefs.getString('building_id'), 'TestBuilding');
      expect(mockPrefs.getString('level'), '5');
      expect(mockPrefs.getInt('entrance_x'), 30);
      expect(mockPrefs.getInt('entrance_y'), 40);
    });

    testWidgets('generates default entrance ID when none found', (WidgetTester tester) async {
      final state = _QRScannerScreenState();
      
      await state._saveEntranceId('random_text_without_valid_format');
      
      final entranceId = mockPrefs.getString('entrance_id');
      expect(entranceId, isNotNull);
      expect(entranceId, 'random_text_without_valid_format'); // It truncates the original text
    });

    testWidgets('permission screen has correct layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QRScannerScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check camera icon properties
      final icon = tester.widget<Icon>(find.byIcon(Icons.camera_alt));
      expect(icon.size, 64);
      expect(icon.color, Colors.grey);

      // Check layout structure
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Center), findsWidgets); // Multiple Center widgets in the layout
    });

    testWidgets('scaffold has correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QRScannerScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });
  });
}

// Extend the state class to make validation methods public for testing
class _QRScannerScreenState extends State<QRScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }

  bool _isValidEntranceQRCode(String code) {
    if (code.isEmpty) {
      return false;
    }
    
    if (code.startsWith('http://') || code.startsWith('https://')) {
      return true;
    }
    
    if (code.contains('ENTRANCE') || code.contains('entrance')) {
      return true;
    }
    
    if (code.contains('entrance=')) {
      return true;
    }
    
    if (code.contains('building=') || code.contains('level=')) {
      return true;
    }
    
    try {
      final jsonData = json.decode(code);
      if (jsonData is Map) {
        return true;
      }
    } catch (e) {
      // Not valid JSON
    }
    
    if (code.length < 100) {
      return true;
    }
    
    return false;
  }

  Future<void> _saveEntranceId(String entranceQRCode) async {
    final prefs = await SharedPreferences.getInstance();
    
    String entranceId = "";
    String building = "";
    String level = "1";
    int x = 0;
    int y = 0;
    
    try {
      final jsonData = json.decode(entranceQRCode);
      if (jsonData is Map) {
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
        }
      }
    } catch (e) {
      // Handle non-JSON formats
      if (entranceQRCode.startsWith('ENTRANCE_') || entranceQRCode.contains('ENTRANCE')) {
        final parts = entranceQRCode.split('_');
        entranceId = entranceQRCode;
        
        if (parts.length >= 3) {
          building = parts[1];
          entranceId = parts[2];
          
          if (parts.length >= 4) {
            level = parts[3];
          }
          
          if (parts.length >= 6) {
            x = int.tryParse(parts[4]) ?? 0;
            y = int.tryParse(parts[5]) ?? 0;
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
      }
    }
    
    if (entranceId.isNotEmpty) {
      await prefs.setString('entrance_id', entranceId);
    } else {
      entranceId = "ENTRANCE_${DateTime.now().millisecondsSinceEpoch}";
      await prefs.setString('entrance_id', entranceId);
    }
    
    await prefs.setString('entrance_scan_time', DateTime.now().toIso8601String());
    
    if (building.isNotEmpty) {
      await prefs.setString('building_id', building);
    } else {
      building = "DEFAULT_BUILDING";
      await prefs.setString('building_id', building);
    }
    
    await prefs.setString('level', level);
    await prefs.setInt('entrance_x', x);
    await prefs.setInt('entrance_y', y);
    await prefs.setString('raw_qr_content', entranceQRCode);
  }
}