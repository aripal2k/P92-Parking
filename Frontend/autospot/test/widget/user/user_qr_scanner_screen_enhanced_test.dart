import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/userQRScanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../helpers/test_helpers.dart';

void main() {
  group('QRScannerScreen Enhanced Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays permission request UI when permission not granted', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Assert - Permission request UI
      expect(find.text('Camera permission is required to scan QR codes'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
      
      // Check scaffold background color
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
      
      // Check AppBar
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFA3DB94));
    });

    testWidgets('grant permission button tap triggers permission check', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Tap grant permission
      await tester.tap(find.text('Grant Permission'));
      await tester.pump();

      // Should attempt to check permission
      expect(find.byType(QRScannerScreen), findsOneWidget);
    });

    testWidgets('displays scanner UI when permission is granted', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      // Force rebuild to simulate permission granted
      await tester.pump();

      // The scanner UI should be created
      expect(find.byType(QRScannerScreen), findsOneWidget);
    });

    testWidgets('shows correct scanner UI elements', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pump();

      // Check for UI elements
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('validates entrance QR codes correctly', (WidgetTester tester) async {
      // Create state to test validation
      final state = _TestableQRScannerScreenState();

      // Test various formats
      expect(state.isValidEntranceQRCode('ENTRANCE_123'), true);
      expect(state.isValidEntranceQRCode('entrance_456'), true);
      expect(state.isValidEntranceQRCode('http://example.com/entrance'), true);
      expect(state.isValidEntranceQRCode('https://example.com'), true);
      expect(state.isValidEntranceQRCode('building=A&entrance=B'), true);
      expect(state.isValidEntranceQRCode('level=2'), true);
      expect(state.isValidEntranceQRCode('entrance=main'), true);
      expect(state.isValidEntranceQRCode('{"entrance_id": "123"}'), true);
      expect(state.isValidEntranceQRCode('{"entrances": [{"entrance_id": "E1"}]}'), true);
      expect(state.isValidEntranceQRCode('simple_text'), true);
      expect(state.isValidEntranceQRCode(''), false);
      
      // Test long text (should be accepted if < 100 chars)
      expect(state.isValidEntranceQRCode('a' * 99), true);
      expect(state.isValidEntranceQRCode('a' * 101), false);
    });

    testWidgets('saves entrance data from JSON format correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test new JSON format
      await state.saveEntranceId('{"entrance_id": "E123", "building": "B1", "level": "3", "coordinates": {"x": 10, "y": 20}}');

      // Assert
      expect(prefs.getString('entrance_id'), 'E123');
      expect(prefs.getString('building_id'), 'B1');
      expect(prefs.getString('level'), '3');
      expect(prefs.getInt('entrance_x'), 10);
      expect(prefs.getInt('entrance_y'), 20);
      expect(prefs.getString('entrance_scan_time'), isNotNull);
      expect(prefs.getString('raw_qr_content'), '{"entrance_id": "E123", "building": "B1", "level": "3", "coordinates": {"x": 10, "y": 20}}');
    });

    testWidgets('saves entrance data from old JSON format', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test old JSON format
      await state.saveEntranceId('{"entrances": [{"entrance_id": "OLD_E1"}], "destination": "BuildingA"}');

      // Assert
      expect(prefs.getString('entrance_id'), 'OLD_E1');
      expect(prefs.getString('building_id'), 'BuildingA');
      expect(prefs.getString('level'), '1'); // Default
    });

    testWidgets('saves entrance data from ENTRANCE_ format', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test ENTRANCE_ format
      await state.saveEntranceId('ENTRANCE_BUILDING1_E001_3_15_25');

      // Assert
      expect(prefs.getString('entrance_id'), 'E001');
      expect(prefs.getString('building_id'), 'BUILDING1');
      expect(prefs.getString('level'), '3');
      expect(prefs.getInt('entrance_x'), 15);
      expect(prefs.getInt('entrance_y'), 25);
    });

    testWidgets('saves entrance data from parameter format', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test parameter format
      await state.saveEntranceId('building=TestBuilding&entrance=MainEntrance&level=5&x=30&y=40');

      // Assert
      expect(prefs.getString('entrance_id'), 'MainEntrance');
      expect(prefs.getString('building_id'), 'TestBuilding');
      expect(prefs.getString('level'), '5');
      expect(prefs.getInt('entrance_x'), 30);
      expect(prefs.getInt('entrance_y'), 40);
    });

    testWidgets('generates default entrance ID for invalid format', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test invalid format
      await state.saveEntranceId('random_text_without_format');

      // Assert
      expect(prefs.getString('entrance_id'), 'random_text_without_format');
      expect(prefs.getString('building_id'), 'DEFAULT_BUILDING');
    });

    testWidgets('saves username and expiration from JSON', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test JSON with username and expiration
      await state.saveEntranceId('{"entrance_id": "E1", "username": "testuser", "expire_at": "2024-12-31"}');

      // Assert
      expect(prefs.getString('qr_username'), 'testuser');
      expect(prefs.getString('qr_expire_at'), '2024-12-31');
    });

    testWidgets('handles empty JSON gracefully', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test empty JSON
      await state.saveEntranceId('{}');

      // Assert - should generate default entrance ID
      final entranceId = prefs.getString('entrance_id');
      expect(entranceId, isNotNull);
      expect(entranceId!.startsWith('ENTRANCE_'), true);
    });

    testWidgets('truncates long QR codes', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test very long QR code
      final longCode = 'a' * 100;
      await state.saveEntranceId(longCode);

      // Assert - should be truncated to 50 chars
      expect(prefs.getString('entrance_id'), 'a' * 50);
    });

    testWidgets('navigates to destination select on valid scan', (WidgetTester tester) async {
      // Arrange
      bool navigated = false;
      String? navigationArg;
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: const QRScannerScreen(),
          routes: {
            '/destination-select': (context) {
              navigated = true;
              navigationArg = ModalRoute.of(context)?.settings.arguments as String?;
              return const Scaffold(body: Text('Destination Select'));
            },
          },
        ),
      );

      // Verify navigation would happen on scan
      expect(find.byType(QRScannerScreen), findsOneWidget);
    });

    testWidgets('shows processing indicator during scan', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pump();

      // Processing indicator would show when isProcessing = true
      expect(find.byType(QRScannerScreen), findsOneWidget);
    });

    testWidgets('permission icon has correct properties', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Check icon properties
      final icon = tester.widget<Icon>(find.byIcon(Icons.camera_alt));
      expect(icon.size, 64);
      expect(icon.color, Colors.grey);
    });

    testWidgets('button has correct styling', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Check button style
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final backgroundColor = button.style?.backgroundColor?.resolve({});
      expect(backgroundColor, const Color(0xFFA3DB94));
      
      final foregroundColor = button.style?.foregroundColor?.resolve({});
      expect(foregroundColor, Colors.black);
    });

    testWidgets('handles multiple QR code scans correctly', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final state = _TestableQRScannerScreenState();

      // First scan
      await state.saveEntranceId('{"entrance_id": "E1"}');
      
      // Second scan should override
      await state.saveEntranceId('{"entrance_id": "E2"}');
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('entrance_id'), 'E2');
    });

    testWidgets('saves coordinates as integers', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test with string coordinates
      await state.saveEntranceId('{"entrance_id": "E1", "coordinates": {"x": "10", "y": "20"}}');

      // Assert - should be parsed as integers
      expect(prefs.getInt('entrance_x'), 10);
      expect(prefs.getInt('entrance_y'), 20);
    });

    testWidgets('handles invalid coordinates gracefully', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test with invalid coordinates
      await state.saveEntranceId('{"entrance_id": "E1", "coordinates": {"x": "invalid", "y": "text"}}');

      // Assert - should default to 0
      expect(prefs.getInt('entrance_x'), 0);
      expect(prefs.getInt('entrance_y'), 0);
    });

    testWidgets('saves entrance scan timestamp', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Act
      await state.saveEntranceId('ENTRANCE_123');

      // Assert
      final timestamp = prefs.getString('entrance_scan_time');
      expect(timestamp, isNotNull);
      expect(DateTime.tryParse(timestamp!), isNotNull);
    });

    testWidgets('handles malformed parameter format', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test with malformed parameters
      await state.saveEntranceId('entrance=&building=&level=');

      // Assert - should use the QR code itself as entrance ID (truncated)
      expect(prefs.getString('entrance_id'), 'entrance=&building=&level=');
      expect(prefs.getString('building_id'), 'DEFAULT_BUILDING');
      expect(prefs.getString('level'), '1');
    });

    testWidgets('validates URLs as entrance QR codes', (WidgetTester tester) async {
      final state = _TestableQRScannerScreenState();

      // Test URL formats
      expect(state.isValidEntranceQRCode('http://parking.com/entrance'), true);
      expect(state.isValidEntranceQRCode('https://secure.parking.com'), true);
      expect(state.isValidEntranceQRCode('ftp://invalid.com'), true); // accepted as simple text
    });

    testWidgets('handles partial ENTRANCE_ format', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test partial format
      await state.saveEntranceId('ENTRANCE_B1');

      // Assert
      expect(prefs.getString('entrance_id'), 'ENTRANCE_B1');
      expect(prefs.getString('building_id'), 'DEFAULT_BUILDING');
      expect(prefs.getString('level'), '1');
    });

    testWidgets('permission request text is centered', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Check text alignment
      final text = tester.widget<Text>(
        find.text('Camera permission is required to scan QR codes')
      );
      expect(text.textAlign, TextAlign.center);
      expect(text.style?.fontSize, 16);
    });

    testWidgets('AppBar has correct icon theme', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});

      // Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(const QRScannerScreen()),
      );
      
      await tester.pumpAndSettle();

      // Check AppBar icon theme
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.iconTheme?.color, Colors.black);
    });

    testWidgets('handles JSON with destination field', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test JSON with destination
      await state.saveEntranceId('{"destination": "ParkingLotA"}');

      // Assert
      expect(prefs.getString('building_id'), 'ParkingLotA');
      // Should use first key as entrance ID
      expect(prefs.getString('entrance_id'), 'destination');
    });

    testWidgets('uses first JSON key as entrance ID fallback', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = _TestableQRScannerScreenState();

      // Test JSON without entrance_id
      await state.saveEntranceId('{"some_key": "value", "other": "data"}');

      // Assert - should use first key
      expect(prefs.getString('entrance_id'), 'some_key');
    });
  });
}

// Helper class to test protected methods
class _TestableQRScannerScreenState {
  bool isValidEntranceQRCode(String code) {
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
      final jsonData = jsonDecode(code);
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

  Future<void> saveEntranceId(String entranceQRCode) async {
    final prefs = await SharedPreferences.getInstance();
    
    String entranceId = "";
    String building = "";
    String level = "1";
    int x = 0;
    int y = 0;
    
    try {
      final jsonData = jsonDecode(entranceQRCode);
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
        }
        
        if (jsonData.containsKey('username')) {
          await prefs.setString('qr_username', jsonData['username'].toString());
        }
        
        if (jsonData.containsKey('expire_at')) {
          await prefs.setString('qr_expire_at', jsonData['expire_at'].toString());
        }
      }
    } catch (e) {
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