import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/qr_scanner_web.dart';

void main() {
  group('QR Scanner Web Tests', () {
    testWidgets('buildQRScanner returns web fallback widget', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) {},
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert
      expect(find.text('QR Scanner not available on Web'), findsOneWidget);
      expect(find.text('Please use the mobile app'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('buildQRScanner uses provided key', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'TestQRKey');
      
      // Act
      final widget = buildQRScanner(
        qrKey: qrKey,
        onQRViewCreated: (_) {},
        cutOutSize: 300.0,
      );
      
      // Assert
      expect((widget as Container).key, equals(qrKey));
    });

    testWidgets('buildQRScanner has correct styling', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) {},
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert - Container styling
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.black);
      expect(decoration.border, isNotNull);
      expect(decoration.border!.top.color, const Color(0xFFA3DB94));
      expect(decoration.border!.top.width, 3);
    });

    testWidgets('icon has correct properties', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) {},
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert
      final icon = tester.widget<Icon>(find.byIcon(Icons.qr_code_scanner));
      expect(icon.size, 80);
      expect(icon.color, Colors.white);
    });

    testWidgets('text widgets have correct styling', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) {},
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert - Main text
      final mainText = tester.widget<Text>(find.text('QR Scanner not available on Web'));
      expect(mainText.style!.color, Colors.white);
      expect(mainText.style!.fontSize, 18);
      
      // Assert - Sub text
      final subText = tester.widget<Text>(find.text('Please use the mobile app'));
      expect(subText.style!.color, Colors.white70);
    });

    testWidgets('layout is properly structured', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) {},
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert
      expect(find.byType(Center), findsWidgets);
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(SizedBox), findsAtLeastNWidgets(2)); // At least two SizedBox widgets
    });

    test('QrScannerOverlayShape default values', () {
      // Arrange & Act
      const shape = QrScannerOverlayShape(cutOutSize: 250.0);
      
      // Assert
      expect(shape.borderColor, Colors.red);
      expect(shape.borderWidth, 3.0);
      expect(shape.borderRadius, 0);
      expect(shape.borderLength, 40);
      expect(shape.cutOutSize, 250.0);
    });

    test('QrScannerOverlayShape custom values', () {
      // Arrange & Act
      const shape = QrScannerOverlayShape(
        borderColor: Colors.green,
        borderWidth: 5.0,
        borderRadius: 8.0,
        borderLength: 45.0,
        cutOutSize: 350.0,
      );
      
      // Assert
      expect(shape.borderColor, Colors.green);
      expect(shape.borderWidth, 5.0);
      expect(shape.borderRadius, 8.0);
      expect(shape.borderLength, 45.0);
      expect(shape.cutOutSize, 350.0);
    });

    testWidgets('buildQRScanner callback is stored but not used', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      bool callbackCalled = false;
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) { callbackCalled = true; },
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert - Callback should not be called in web version
      expect(callbackCalled, false);
    });

    testWidgets('spacing between elements is correct', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) {},
              cutOutSize: 250.0,
            ),
          ),
        ),
      );
      
      // Assert - Check SizedBox heights
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final heights = sizedBoxes.map((box) => box.height).toList();
      expect(heights, contains(20)); // Space after icon
      expect(heights, contains(10)); // Space between texts
    });

    test('QrScannerOverlayShape is a simple data class', () {
      // This test verifies that QrScannerOverlayShape is just a data holder
      const shape1 = QrScannerOverlayShape(cutOutSize: 250.0);
      const shape2 = QrScannerOverlayShape(cutOutSize: 250.0);
      
      // Same parameters should create equal objects
      expect(shape1.cutOutSize, equals(shape2.cutOutSize));
      expect(shape1.borderColor, equals(shape2.borderColor));
    });
  });
}