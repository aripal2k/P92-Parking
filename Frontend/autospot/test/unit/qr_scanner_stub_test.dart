import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/user/qr_scanner_stub.dart';

void main() {
  group('QR Scanner Stub Tests', () {
    testWidgets('buildQRScanner returns fallback widget', (WidgetTester tester) async {
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
      expect(find.text('QR Scanner not available on this platform'), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('buildQRScanner ignores parameters', (WidgetTester tester) async {
      // Arrange
      final GlobalKey qrKey = GlobalKey(debugLabel: 'TestKey');
      bool callbackCalled = false;
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildQRScanner(
              qrKey: qrKey,
              onQRViewCreated: (_) { callbackCalled = true; },
              cutOutSize: 500.0,
            ),
          ),
        ),
      );
      
      // Assert - Same widget regardless of parameters
      expect(find.text('QR Scanner not available on this platform'), findsOneWidget);
      expect(callbackCalled, false); // Callback never called in stub
    });

    test('QRScannerOverlayShape default values', () {
      // Arrange & Act
      const shape = QRScannerOverlayShape(cutOutSize: 250.0);
      
      // Assert
      expect(shape.borderColor, Colors.red);
      expect(shape.borderWidth, 3.0);
      expect(shape.borderRadius, 0);
      expect(shape.borderLength, 40);
      expect(shape.cutOutSize, 250.0);
    });

    test('QRScannerOverlayShape custom values', () {
      // Arrange & Act
      const shape = QRScannerOverlayShape(
        borderColor: Colors.blue,
        borderWidth: 5.0,
        borderRadius: 10.0,
        borderLength: 50.0,
        cutOutSize: 300.0,
      );
      
      // Assert
      expect(shape.borderColor, Colors.blue);
      expect(shape.borderWidth, 5.0);
      expect(shape.borderRadius, 10.0);
      expect(shape.borderLength, 50.0);
      expect(shape.cutOutSize, 300.0);
    });

    test('QRScannerOverlayShape dimensions', () {
      // Arrange & Act
      const shape = QRScannerOverlayShape(cutOutSize: 250.0);
      
      // Assert
      expect(shape.dimensions, EdgeInsets.zero);
    });

    test('QRScannerOverlayShape paths', () {
      // Arrange
      const shape = QRScannerOverlayShape(cutOutSize: 250.0);
      final rect = Rect.fromLTWH(0, 0, 100, 100);
      
      // Act
      final innerPath = shape.getInnerPath(rect);
      final outerPath = shape.getOuterPath(rect);
      
      // Assert
      expect(innerPath, isA<Path>());
      expect(outerPath, isA<Path>());
    });

    testWidgets('QRScannerOverlayShape paint method', (WidgetTester tester) async {
      // Arrange
      const shape = QRScannerOverlayShape(cutOutSize: 250.0);
      
      // Act & Assert - Paint method exists and can be called
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: TestPainter(shape),
          ),
        ),
      );
      
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('QRScannerOverlayShape scale method', () {
      // Arrange
      const shape = QRScannerOverlayShape(cutOutSize: 250.0);
      
      // Act
      final scaledShape = shape.scale(2.0);
      
      // Assert - Scale returns same instance (stub implementation)
      expect(scaledShape, same(shape));
    });

    testWidgets('buildQRScanner works in different screen sizes', (WidgetTester tester) async {
      // Test different screen sizes
      final sizes = [
        const Size(360, 640),  // Small phone
        const Size(414, 896),  // iPhone 11
        const Size(768, 1024), // Tablet
      ];

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: buildQRScanner(
                qrKey: GlobalKey(),
                onQRViewCreated: (_) {},
                cutOutSize: 250.0,
              ),
            ),
          ),
        );

        expect(find.text('QR Scanner not available on this platform'), findsOneWidget);
      }

      // Reset
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

class TestPainter extends CustomPainter {
  final QRScannerOverlayShape shape;
  
  TestPainter(this.shape);
  
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    shape.paint(canvas, rect);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}