import 'package:flutter/material.dart';

// Function that returns a placeholder widget for platforms
// where the QR scanner is not available (e.g., web, unsupported OS)
Widget buildQRScanner({
  required GlobalKey qrKey,
  required Function(dynamic) onQRViewCreated,
  required double cutOutSize,
}) {
  return const Center(
    child: Text('QR Scanner not available on this platform'),
  );
}


// Custom overlay shape for the QR scanner
class QRScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QRScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.borderRadius = 0,
    this.borderLength = 40,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}